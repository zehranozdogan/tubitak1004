"""Tazelik durumuna göre reaktif modül renkleri (rapor §5, §7, §8).

Kavram: reaktif modül renklense bile QR'ın kendi açık/koyu (0/1) sınıfını
bozmamalı ki decoder hâlâ okuyabilsin (rapor §5.2 adım 3: "Her reaktif
rengin gri-seviye/binary davranışını incele... orijinal siyah/beyaz
sınıfını değiştirmeyen pozisyonlara yerleştir"). Bu yüzden her durum için
İKİ ton tanımlanır: bit=1 (koyu modül) → 'dark', bit=0 (açık modül) → 'light'.

DEĞERLER: `packages/profile_schema/examples/GENIPIN_PUTRESIN_v2.sensor_profile.json`
scale_points'inden türetildi — gerçek Putresin deney fotoğraflarına dayanan
renkler (rapor §4: "Putresin çözeltilerinden elde edilen renkler.pptx"),
uydurma/keyfi demo renkleri DEĞİL. 6 nokta (0.03125..1.0 mM), en soluk ikisi
fresh, ortadaki ikisi transition, en koyu ikisi spoiled'a eşlendi — her
durumda daha düşük konsantrasyon = 'light', daha yüksek = 'dark' (bit
sınıfına göre, kimyasal anlam değil). Decodability
tests/synthetic/test_decode_verification.py ile doğrulanır (bu dosyayı
her değiştirdiğinde o test paketini tekrar çalıştır).
"""

RGB = tuple[int, int, int]

STATE_LABELS = {
    "fresh": "Taze",
    "transition": "Geçiş",
    "spoiled": "Bozuk",
}

STATE_COLORS: dict[str, dict[str, RGB]] = {
    "fresh": {"light": (214, 205, 196), "dark": (193, 176, 160)},       # 0.03125 / 0.0625 mM
    "transition": {"light": (150, 128, 112), "dark": (110, 92, 84)},    # 0.125 / 0.25 mM
    "spoiled": {"light": (78, 66, 66), "dark": (54, 50, 58)},           # 0.5 / 1.0 mM
}

# Henüz bir duruma atanmamış / yalnızca yerleşimi göstermek için nötr gri.
NEUTRAL: dict[str, RGB] = {"dark": (97, 97, 97), "light": (224, 224, 224)}


def module_color(bit: int, is_sensor: bool, state: str | None) -> RGB:
    """Tek bir modülün rengini döndürür.

    bit: modülün orijinal QR biti (1=koyu, 0=açık)
    is_sensor: bu modül reaktif sensör hücresi mi (layout['sensor_modules'])
    state: "fresh" | "transition" | "spoiled" | None (None -> nötr gri)
    """
    if not is_sensor:
        return (0, 0, 0) if bit else (255, 255, 255)
    tones = STATE_COLORS.get(state, NEUTRAL) if state else NEUTRAL
    return tones["dark"] if bit else tones["light"]


def module_pixel_center(row: int, col: int, *, scale: int, border: int) -> tuple[int, int]:
    """Bir QR modülünün (satır, sütun) rasterize edilmiş görüntüdeki piksel
    merkezi — `packages.qr_layout.render`'daki ölçeklemeyle AYNI formül
    (`x0 = (c + border) * scale` vb.). Dönen (satır=piksel_y, sütun=piksel_x)
    sırası, bir numpy görüntü dizisinde `image[y, x]` ile eşleşir.
    """
    x = (col + border) * scale + scale // 2
    y = (row + border) * scale + scale // 2
    return (y, x)


# Sol-üst finder pattern'in her QR versiyonunda GARANTİ siyah/beyaz olan
# iki modülü (ISO/IEC 18004, versiyon bağımsız): dış halka (satır/sütun 0
# ve 6) hep SİYAH, bir içi (iç çekirdek hariç) hep BEYAZ, iç 3x3 çekirdek
# (2..4, 2..4) hep SİYAH. `packages.color_engine.pipeline` bu sabitleri
# referans örnekleme için kullanır (rapor §6.1 D).
FINDER_BLACK_MODULE = (3, 3)
FINDER_WHITE_MODULE = (1, 1)


def finder_pattern_reference_pixels(*, scale: int, border: int) -> dict[str, tuple[int, int]]:
    """FINDER_BLACK_MODULE / FINDER_WHITE_MODULE'ün piksel merkezlerini
    döndürür (rapor §6.1 D: ek baskılı referans yaması gerektirmeyen
    kalibrasyon — reaktif hücreler bunlara dokunmaz, §5.1 "değiştirilemeyecek
    bölgeler").
    """
    return {
        "black": module_pixel_center(*FINDER_BLACK_MODULE, scale=scale, border=border),
        "white": module_pixel_center(*FINDER_WHITE_MODULE, scale=scale, border=border),
    }


# --- Etiket kenarı referans yaması (rapor §5.2/5'in "QR içinde VEYA etiket
# kenarında" alternatiflerinden ikincisi — bkz. render.py::render_with_
# edge_gray_patch ve tests/synthetic/benchmark_edge_reference.py). ---
#
# QR-içi (yukarıdaki finder pattern) yöntemi sadece siyah/beyaz verebilir;
# gerçek bir GRİ referans (§6.1 B: white_gray_black) için QR'ın DIŞINDA,
# zorunlu quiet zone'un da dışında, ayrı bir baskı alanı gerekir.
GRAY_REFERENCE_RGB: RGB = (128, 128, 128)
EDGE_PATCH_MARGIN = 4  # zorunlu quiet zone'un dışında, SADECE yama için ek modül şeridi
EDGE_PATCH_SIZE = 3  # yamanın modül cinsinden kare kenar uzunluğu


def edge_gray_patch_position(matrix_size: int, *, border: int) -> tuple[int, int]:
    """Gri yamanın SANAL (satır, sütun) konumu — üst kenar, ortalanmış,
    `border` (gerçek/zorunlu quiet zone) modül kadar QR'dan uzakta BAŞLAYAN
    EDGE_PATCH_MARGIN şeridinin ortasında. Gerçek bir QR modülü değildir;
    `module_pixel_center` ve `sample_module_roi`, render/pipeline'da
    kullanılan TOPLAM border (`border + EDGE_PATCH_MARGIN`) ile çağrılırsa
    doğru pikseli verir — negatif satır bu yüzden çalışır, ayrı bir
    koordinat sistemi gerekmez (rapor §10.1: okuyucu koordinatları
    hard-code etmesin, hepsi aynı (satır, sütun) sözleşmesiyle
    layout_version'da taşınabiliyor)."""
    center_row = -(border + EDGE_PATCH_MARGIN // 2 + 1)
    return (center_row, matrix_size // 2)


# --- Çoklu renk yaması (rapor §6.1 C: "3x3/çok renkli düzeltme matrisi" —
# `calibration.multicolor_patch`, >=4 nokta gerektirir). Tek gri nokta
# (yukarısı, §6.1 B) yalnızca parlaklık eksenini düzeltir; bu ek kanallar
# ARASI karışımı da (ör. kırmızının yeşile sızması) düzeltebilir — ama bunu
# YAPABİLMESİ için gerçekten FARKLI renklerde referans noktası gerekir,
# aynı grinin tekrar örneklenmesi işe yaramaz (elle ölçüldü, bkz.
# tests/device/results_2026-09-17.md: 5 noktalı gri ortalaması 1 noktadan
# hiç daha iyi çıkmadı).
EDGE_REFERENCE_COLORS: dict[str, RGB] = {
    "gray": GRAY_REFERENCE_RGB,
    "red": (205, 40, 40),
    "green": (35, 150, 70),
    "blue": (35, 95, 190),
}


def edge_patch_positions(matrix_size: int, *, border: int, colors: dict[str, RGB] | None = None) -> dict[str, tuple[int, int]]:
    """Her adlandırılmış kenar yamasının SANAL (satır, sütun) konumu — üst
    kenar şeridinde, çakışmayacak şekilde yan yana dizilir (en az
    `EDGE_PATCH_SIZE + 2` modül aralıkla, ortalanmış)."""
    colors = colors if colors is not None else EDGE_REFERENCE_COLORS
    names = list(colors)
    n = len(names)
    row = -(border + EDGE_PATCH_MARGIN // 2 + 1)
    step = EDGE_PATCH_SIZE + 2  # çakışmayı önlemek için yama genişliği + güvenlik payı
    center_col = matrix_size // 2
    start_col = center_col - (n - 1) * step // 2
    return {name: (row, start_col + i * step) for i, name in enumerate(names)}
