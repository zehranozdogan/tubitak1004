"""Renk motoru ana akışı (rapor §6.2).

`image`: BGR numpy dizisi (decode.py/quality.py ile aynı sözleşme).

`layout_version.reference_regions` artık üretici tarafında dolduruluyor
(qr_layout/reactive.py::build_layout(), varsayılan: QR'ın finder pattern
sabitleri — D yöntemi, ek baskılı yama gerektirmez, reaktif hücreler bu
sabit bölgeye dokunmaz, §5.1). Eski/elle kurulmuş layout_version'larda bu
alan yoksa QR sabitlerine düşülür (geriye dönük uyumluluk).

B (white_gray_black) ve C (multicolor_patch) artık OKUYUCU tarafında da
gerçekten kullanılıyor (20 Eylül) — üretici (qr_layout/render.py::
render_label_image) bunları basıp reference_regions'a yazıyordu, önceden
bu dosya onları görmezden gelip hep white_black'e düşüyordu; artık
düzeltildi. `reference_regions` gerekli anahtarları içermiyorsa (eski
layout veya A/D profili) hâlâ white_black'e düşer, ama artık sessizce
değil — notes'a yazılarak.

`confidence` (18 Eylül eklendi): reaktif modül okumalarının BİRBİRİYLE NE
KADAR TUTARLI olduğuna dayanır (her modülün temsilci/median renkten ΔE
sapması). DAYANAK — uydurulmadı, ölçüldü (64 sentetik açı×bulanıklık×
parlaklık kombinasyonu, DEMO_QR_STATE_COLORS_v1 ile): doğru sınıflandırılan
sonuçlarda ortalama sapma 7.54 (n=51), YANLIŞ sınıflandırılanlarda 19.34
(n=13) — net bir ayrım var, mükemmel değil (orta bantta örtüşme var, bu
YANSITILIYOR: confidence orada da orta değer verir, uçlara zıplamaz).

Referans köşe tutarlılığı (21 Eylül eklendi, bkz.
`_reference_corner_consistency`): QR'ın üç finder köşesindeki BEYAZ
referans ayrı ayrı örneklenip birbirleriyle karşılaştırılır — düzensiz
ışıkta (flaş noktası, gölge) bu üçü ayrışır. SADECE notes'a bilgi eklemek
için kullanılır, confidence'ı SAYISAL olarak ETKİLEMEZ. İKİ AŞAMADA
YUMUŞATILDI: önce (aynı gün) layout-farkında OLMAYAN bir sezgisel (ham
piksel kenar örneklemesi) denendi, hem sentetik hem GERÇEK fotoğraflarla
güvenilmez bulundu (bkz. tests/synthetic/test_realistic_distortions.py).
Sonra layout-farkında bu yöntem geldi ve confidence'a bir ÇARPAN olarak
eklendi — ama 2 gerçek fotoğraf + üzerlerine eklenen KÜÇÜK ek gölgelerle
test edilince o çarpan da fazla sert çıktı (bilinen iyi bir fotoğrafta
0.775 olan çarpan, yarım çerçeveye %50 hafif kararma eklenince 0.237'ye
düşüyordu). N=2 gerçek veriyle sayısal bir çarpan haklı çıkarılamaz —
şimdilik yalnızca bilgilendirici not (bkz. _reference_corner_consistency
docstring'inin sonu, kullanıcı geri bildirimiyle 21 Eylül'de düzeltildi).
"""

from __future__ import annotations

import numpy as np

from packages.color_engine import calibration
from packages.color_engine.colorspace import delta_e, rgb_to_lab
from packages.color_engine.homography import warp_to_canonical
from packages.color_engine.matching import match_profile_point
from packages.color_engine.quality import quality_score, should_rescan
from packages.color_engine.roi import robust_module_color, sample_module_roi
from packages.color_engine.types import ColorEngineResult, ModuleReading, Rgb
from packages.qr_layout.colors import (
    EDGE_REFERENCE_COLORS,
    FINDER_BLACK_MODULE,
    FINDER_WHITE_MODULE,
    finder_pattern_corner_positions,
)
from packages.qr_layout.decode import decode_qr_image_with_corners

Image = np.ndarray

# Canonical (homografi sonrası) görüntünün rasterize parametreleri —
# packages.qr_layout.render'daki üretici varsayılanlarıyla AYNI olmalı.
_CANONICAL_SCALE = 10
_CANONICAL_BORDER = 4

# reference_regions dolmadan doğrudan (yalnızca beyaz/siyah referansla)
# çalışabilen yöntemler.
_SUPPORTED_WITHOUT_EXTRA_REFERENCES = {"white_black", "qr_fixed_regions", "algorithmic_white_balance"}

# BGR sırasında "gerçek" referans renkleri — `canonical` BGR olduğu için
# (modül başlığı). EDGE_REFERENCE_COLORS (qr_layout/colors.py) RGB tanımlı;
# burada BGR'a çevrilir. DİKKAT: bu dönüşüm atlanırsa multicolor_patch
# kanalları karıştırır (elle bulunmuş gerçek bir hata, bkz. tests/device/
# results_2026-09-17c.md) — A/D/B'de fark edilmez çünkü white/black/gray
# simetriktir, yalnızca çoklu-renkte ortaya çıkar.
_REFERENCE_TRUE_COLORS_BGR = {
    "white": (255, 255, 255),
    "black": (0, 0, 0),
    **{name: tuple(reversed(rgb)) for name, rgb in EDGE_REFERENCE_COLORS.items()},
}

# confidence formülü için doygunluk noktası: modül-okuma sapması (ΔE, bkz.
# _module_reading_confidence) bu değere ULAŞTIĞINDA confidence 0'a iner.
# ELLE ÖLÇÜLDÜ (modül başlığındaki not) — uydurulmadı: 64 sentetik test
# kombinasyonunda doğru sonuçlar ort. 7.5, yanlışlar ort. 19.3 sapma
# veriyordu; 20 bu ikisinin arasında, yanlışların sınırına yakın bir eşik.
_SPREAD_SATURATING_DELTA_E = 20.0

# confidence formülünün TABAN noktası (21 Eylül eklendi — kullanıcı geri
# bildirimi: "çok iyi şartlarda çekilmiş fotoğrafta bile confidence 0.64
# ise..."). SEBEP: aynı durumun (ör. 'fresh') QR bitine göre iki farklı
# tonu (koyu/açık, module_color §5.2/3) olduğundan, HİÇ BOZULMA OLMASA
# BİLE sapma asla 0 olmuyor — bu YAPISAL bir taban gürültü. ELLE ÖLÇÜLDÜ
# (bugün, açısız/renk kaymasız sentetik render'larla): fresh/spoiled ~3.2,
# transition ~5.9. Eski formül (0 spread -> 1.0, sadece _SATURATING'e göre
# ölçekli) bu tabanı hesaba katmıyordu — yani TEMİZ bir okuma bile pratikte
# hiçbir zaman ~0.7-0.85'in üstüne çıkamıyordu (gerçek 2 cihaz fotoğrafında
# görüldü: quality_score=1.0, hiç uyarı yok, yine de confidence 0.64/0.72).
# Bu taban artık "yüksek güven" ucuna eşlenir (spread<=4 -> confidence 1.0),
# _SPREAD_SATURATING_DELTA_E ise hâlâ "düşük güven" ucu. NOT: FLOOR bugün
# doğrudan ölçüldü, SATURATING ise hâlâ eski (19 Eylül öncesi) 64-kombinasyon
# taramasından — ikisi FARKLI tarihli kanıta dayanıyor, ileride SATURATING de
# gerçek cihaz verisiyle yeniden doğrulanmalı (rapor §11 Aşama B).
_SPREAD_FLOOR_DELTA_E = 4.0

# Referans köşe tutarsızlığını NOT olarak işaretlemek için eşik (bkz.
# _reference_corner_consistency). SADECE bilgilendirici — confidence'ı
# SAYISAL olarak ÇARPMIYOR (21 Eylül'de önce denendi, geri alındı, bkz. bu
# fonksiyonun docstring'inin sonu). ELLE ÖLÇÜLDÜ: 2 gerçek cihaz fotoğrafında
# (tests/device/manifest.csv, ikisi de İYİ/kullanılabilir okumalar) cv 0.09
# ve 0.15 çıktı; bu ikisinin üzerine SADECE hafif (%10-25) ek bir soldan-sağa
# gölge eklendiğinde bile cv 0.11-0.16'ya çıkıyor — yani gerçek "iyi" ve
# "hafif kötüleşmiş" arasındaki fark bu ölçekte küçük/gürültülü (3 nokta
# üzerinden hesaplanan bir cv, doğası gereği gürültülü). Eşik bilerek bu
# gözlemlenen aralığın BELİRGİN ÜSTÜNE (0.25) konuldu, gerçek cihaz
# testleriyle kalibre edilecek (rapor §11 Aşama B).
_CORNER_CV_NOTE_THRESHOLD = 0.25


def _reference_corner_consistency(canonical: Image, matrix_size: int) -> float:
    """QR'ın üç finder pattern köşesindeki (sol-üst/sağ-üst/sol-alt) BEYAZ
    referans modülünü AYRI AYRI örnekleyip değişim katsayısını (cv) döner —
    üçü de gerçekte AYNI (beyaz) olması gerektiğinden aralarındaki fark
    yalnızca IŞIKTAN (flaş noktası, gölge) kaynaklanabilir; tek noktalı
    kalibrasyon (A/D) bunu düzeltemez. Kasıtlı olarak SADECE beyaz
    kullanılır, siyah değil — siyah modüllerin mutlak parlaklığı çok düşük
    (~10-40/255) olduğundan aynı miktardaki kamera gürültüsü orada
    orantısal olarak çok daha büyük (güvenilmez) bir cv üretiyor (elle
    ölçüldü, gerçek fotoğraflarda siyah-cv 0.45-0.56 iken beyaz-cv 0.09-0.15
    çıktı).

    NOT: bu değer confidence'ı SAYISAL olarak çarpmak için KULLANILMIYOR —
    yalnızca notes'a (bkz. _CORNER_CV_NOTE_THRESHOLD) bilgi eklemek için.
    İlk denemede (21 Eylül) `1 - cv/0.4` gibi bir çarpan confidence'a
    uygulanmıştı; gerçek 2 fotoğraf + üzerlerine eklenen KÜÇÜK ek gölgelerle
    test edilince bu çarpanın aşırı sert olduğu görüldü (bilinen İYİ bir
    fotoğrafta 0.775 olan çarpan, çerçevenin sadece yarısına %50'lik hafif
    bir kararma eklenince 0.237'ye düşüyordu — confidence'ı neredeyse
    sıfırlıyordu). 3 örnekten hesaplanan bir cv'ye bu kadar güvenip sayısal
    bir çarpan üretmek, N=2 gerçek veri noktasıyla haklı çıkarılamayacak
    kadar iddialıydı; geri alındı."""
    positions = finder_pattern_corner_positions(matrix_size)
    whites = []
    for corner in positions.values():
        row, col = corner["white"]
        color = robust_module_color(
            sample_module_roi(canonical, row, col, scale=_CANONICAL_SCALE, border=_CANONICAL_BORDER)
        )
        whites.append(float(np.mean(color)))
    whites_arr = np.array(whites)
    mean = float(whites_arr.mean())
    if mean <= 1e-6:
        return 0.0
    return float(whites_arr.std() / mean)


def _module_reading_confidence(module_readings: list[ModuleReading], representative_lab) -> float:
    """0..1: reaktif modül okumaları BİRBİRİYLE ne kadar tutarlı (düşük
    sapma = yüksek güven). Her modülün temsilci (median) renkten ΔE
    sapmasının ortalamasını alıp [`_SPREAD_FLOOR_DELTA_E`,
    `_SPREAD_SATURATING_DELTA_E`] aralığına göre normalize eder — bu
    aralığın ALTINDAKİ (temiz okumada zaten var olan yapısal taban
    gürültüsü) hiçbir şeyi cezalandırmaz, ÜSTÜNDEKİ her şeyi 0'a satüre
    eder. Tek modüllü bir layout'ta anlamsızca hep 1.0 döner (sapma tanımı
    gereği sıfır) — pratikte `_MIN_CELLS>=5` (qr_layout/reactive.py)
    olduğu için bu durum beklenmez.

    NOT: TEMİZ (bozulmasız) bir görüntüde bile sapma tam 0 OLMAZ — aynı
    durumun (ör. 'fresh') kendi içinde koyu/açık iki tonu var (module_color,
    §5.2/3, QR bitine göre); bu YAPISAL bir taban gürültüdür. Bkz.
    `_SPREAD_FLOOR_DELTA_E` docstring'i: bu taban ARTIK confidence'ı
    tavanlıyor (spread<=floor -> 1.0) — eskiden (20 Eylül'e kadar) doğrudan
    _SATURATING'e göre ölçekleniyordu, yani TEMİZ bir okuma bile ~0.7-0.85'in
    üstüne çıkamıyordu; kullanıcı bunu gerçek fotoğraflarla (0.64/0.72,
    quality_score=1.0) sorguladı, 21 Eylül'de düzeltildi."""
    if not module_readings:
        return 0.0
    spreads = [delta_e(m.lab, representative_lab) for m in module_readings]
    mean_spread = float(np.mean(spreads))
    span = _SPREAD_SATURATING_DELTA_E - _SPREAD_FLOOR_DELTA_E
    return max(0.0, min(1.0, 1.0 - (mean_spread - _SPREAD_FLOOR_DELTA_E) / span))


def _rescan_result(quality: float, note: str) -> ColorEngineResult:
    return ColorEngineResult(quality_score=quality, rescan_recommended=True, notes=[note])


def analyze(
    image: Image,
    sensor_profile: dict,
    layout_version: dict,
    *,
    qr_corners: list[tuple[float, float]] | None = None,
) -> ColorEngineResult:
    """Tek bir kareden tazelik/teknik sonucu üretir (rapor §6.2 adım 1-8)."""
    # 8 (önce kontrol edilir — kötü görüntüde diğer adımlara hiç girilmez, §7.1).
    min_quality = (sensor_profile.get("quality_gate") or {}).get("min_quality_score", 0.5)
    quality = quality_score(image)
    if should_rescan(quality, min_quality):
        return _rescan_result(quality, "Görüntü kalitesi yetersiz (bulanık/parlamalı/karanlık).")

    # 1. QR köşe tespiti (verilmemişse).
    if qr_corners is None:
        _text, qr_corners = decode_qr_image_with_corners(image)
    if qr_corners is None:
        return _rescan_result(quality, "QR köşeleri tespit edilemedi.")

    sensor_modules = layout_version.get("sensor_modules") or []
    if not sensor_modules:
        return _rescan_result(quality, "layout_version.sensor_modules boş; ölçülecek reaktif hücre yok.")

    # 2. Homografi -> canonical görüntü.
    matrix_size = layout_version["matrix_size"]
    canonical = warp_to_canonical(
        image, qr_corners, matrix_size=matrix_size, scale=_CANONICAL_SCALE, border=_CANONICAL_BORDER
    )

    # 2b. Işık düzensizliği için SADECE BİLGİLENDİRİCİ sinyal (bkz.
    #     _reference_corner_consistency docstring) — kapı DEĞİL, confidence'ı
    #     SAYISAL olarak da ETKİLEMEZ; yalnızca belirgin olduğunda notes'a
    #     yazılır (bkz. _CORNER_CV_NOTE_THRESHOLD).
    corner_cv = _reference_corner_consistency(canonical, matrix_size)

    # 3. Kalibrasyon — referans modül konumları layout_version.reference_regions'tan
    #    okunur (§10.1: "okuyucu koordinatları hard-code etmez, bu dosyadan okur").
    #    Eski/elle kurulmuş layout_version'larda bu alan yoksa (geriye dönük
    #    uyumluluk) QR'ın finder pattern sabitlerine düşülür — build_layout()
    #    artık bunu otomatik dolduruyor, bkz. qr_layout/reactive.py.
    #
    #    B (white_gray_black) ve C (multicolor_patch) artık GERÇEKTEN
    #    kullanılıyor (18 Eylül'de eklendi) — üretici (render_label_image,
    #    qr_layout/render.py) bu ek referans yamalarını zaten basıp
    #    reference_regions'a yazıyordu; okuyucu tarafı bunları görmezden
    #    gelip hep white_black'e düşüyordu, bu artık düzeltildi. Yalnızca
    #    reference_regions GERÇEKTEN gerekli anahtarları içermiyorsa (eski
    #    layout_version veya B/C için hiç yama basılmamış) white_black'e
    #    düşülür — sessizce değil, notes'a yazılarak.
    notes: list[str] = []
    if corner_cv > _CORNER_CV_NOTE_THRESHOLD:
        notes.append(
            f"Referans köşeleri arasında parlaklık farkı var (ışık düzensiz olabilir, "
            f"değişim katsayısı {corner_cv:.2f}); yalnızca bilgi amaçlı, confidence "
            "SAYISAL olarak etkilenmedi."
        )

    def _sample_ref(pos: tuple[int, int]) -> tuple[float, float, float]:
        color = robust_module_color(
            sample_module_roi(canonical, *pos, scale=_CANONICAL_SCALE, border=_CANONICAL_BORDER)
        )
        return tuple(color)

    ref_regions = layout_version.get("reference_regions") or {}
    white_pos = tuple(ref_regions["white"][0]) if ref_regions.get("white") else FINDER_WHITE_MODULE
    black_pos = tuple(ref_regions["black"][0]) if ref_regions.get("black") else FINDER_BLACK_MODULE
    white_ref = _sample_ref(white_pos)
    black_ref = _sample_ref(black_pos)

    code = (sensor_profile.get("calibration_method") or {}).get("code", "white_black")
    references: dict = {"white": white_ref, "black": black_ref}

    if code == "white_gray_black":
        if ref_regions.get("gray"):
            references["gray"] = _sample_ref(tuple(ref_regions["gray"][0]))
        else:
            notes.append(
                "Kalibrasyon yöntemi 'white_gray_black' 'gray' referansı istiyor; "
                "layout_version.reference_regions'ta yok, white_black'e düşüldü."
            )
            code = "white_black"

    elif code == "multicolor_patch":
        extra_names = [
            name for name in ref_regions
            if name not in ("white", "black") and name in _REFERENCE_TRUE_COLORS_BGR and ref_regions.get(name)
        ]
        if len(extra_names) + 2 >= 4:  # white+black+ekstra >= 4 nokta (calibration.multicolor_patch şartı)
            references = {
                "captured": [white_ref, black_ref] + [_sample_ref(tuple(ref_regions[n][0])) for n in extra_names],
                "true": [_REFERENCE_TRUE_COLORS_BGR["white"], _REFERENCE_TRUE_COLORS_BGR["black"]]
                + [_REFERENCE_TRUE_COLORS_BGR[n] for n in extra_names],
            }
        else:
            notes.append(
                f"Kalibrasyon yöntemi 'multicolor_patch' >=4 referans noktası istiyor "
                f"({2 + len(extra_names)} bulundu); layout_version.reference_regions yetersiz, "
                "white_black'e düşüldü."
            )
            code = "white_black"

    elif code not in _SUPPORTED_WITHOUT_EXTRA_REFERENCES:
        notes.append(f"Kalibrasyon yöntemi '{code}' desteklenmiyor; white_black'e düşüldü.")
        code = "white_black"

    apply_calibration = calibration.get(code)
    if code == "algorithmic_white_balance":
        corrected = apply_calibration(canonical)
    else:
        corrected = apply_calibration(canonical, references)

    # `image`/`canonical`/`corrected` BGR sırasındadır (decode.py/quality.py
    # ile aynı sözleşme, kalibrasyon matematiği kanal sırasından bağımsızdır).
    # Rgb/Lab için buradan itibaren GERÇEK RGB sırasına çeviriyoruz.
    corrected_rgb = corrected[:, :, ::-1]

    # 4-5. Reaktif hücrelerin ROI örneklemesi (parlama/gölge elenmiş median).
    module_readings: list[ModuleReading] = []
    rgb_samples: list[np.ndarray] = []
    for row, col in sensor_modules:
        patch = sample_module_roi(corrected_rgb, row, col, scale=_CANONICAL_SCALE, border=_CANONICAL_BORDER)
        rgb = robust_module_color(patch)
        rgb_samples.append(rgb)
        lab = rgb_to_lab(Rgb(*rgb))
        module_readings.append(ModuleReading(module=(row, col), normalized_color=Rgb(*rgb), lab=lab))

    # 6. Temsilci renk: modüller arası median (RGB) + Lab.
    representative_rgb = np.median(np.array(rgb_samples), axis=0)
    representative_lab = rgb_to_lab(Rgb(*representative_rgb))

    # 7. sensor_profile.scale_points ile eşleştirme (§7.2 sınıf kuralı dahil).
    match = match_profile_point(representative_lab, sensor_profile)

    return ColorEngineResult(
        quality_score=quality,
        rescan_recommended=False,
        normalized_color=Rgb(*representative_rgb),
        lab=representative_lab,
        delta_e=match["delta_e"],
        matched_profile_point=match["matched_profile_point"],
        freshness_class=match["freshness_class"],
        technical_level=match["technical_level"],
        confidence=_module_reading_confidence(module_readings, representative_lab),
        module_readings=module_readings,
        notes=notes,
    )
