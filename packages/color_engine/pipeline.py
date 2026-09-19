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
from packages.qr_layout.colors import EDGE_REFERENCE_COLORS, FINDER_BLACK_MODULE, FINDER_WHITE_MODULE
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


def _module_reading_confidence(module_readings: list[ModuleReading], representative_lab) -> float:
    """0..1: reaktif modül okumaları BİRBİRİYLE ne kadar tutarlı (düşük
    sapma = yüksek güven). Her modülün temsilci (median) renkten ΔE
    sapmasının ortalamasını alıp `_SPREAD_SATURATING_DELTA_E`'ye göre
    normalize eder. Tek modüllü bir layout'ta anlamsızca hep 1.0 döner
    (sapma tanımı gereği sıfır) — pratikte `_MIN_CELLS>=5` (qr_layout/
    reactive.py) olduğu için bu durum beklenmez.

    NOT: TEMİZ (bozulmasız) bir görüntüde bile sapma tam 0 OLMAZ — aynı
    durumun (ör. 'fresh') kendi içinde koyu/açık iki tonu var (module_color,
    §5.2/3, QR bitine göre); bu YAPISAL bir taban gürültüdür, kalibrasyon
    verisine zaten dahildir (ölçülen en temiz durumda bile sapma ~3.4-4.7)."""
    if not module_readings:
        return 0.0
    spreads = [delta_e(m.lab, representative_lab) for m in module_readings]
    mean_spread = float(np.mean(spreads))
    return max(0.0, min(1.0, 1.0 - mean_spread / _SPREAD_SATURATING_DELTA_E))


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
