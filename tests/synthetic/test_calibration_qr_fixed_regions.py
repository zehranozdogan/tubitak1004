"""qr_fixed_regions() kalibrasyon yöntemi testleri (rapor §6.1 D).

D'nin özelliği: referans renkler ek bir baskı yamasından değil, QR'ın
zaten var olan (hep aynı kalan) finder pattern modüllerinden geliyor.
Bu testler, gerçek bir QR görselini render edip bozup düzelterek uçtan
uca kanıtlıyor: (1) referans olarak KULLANILAN noktalar doğru düzeliyor
mu, (2) düzeltme hiç referans olarak kullanılmamış BAŞKA bir modülde de
(görüntünün geri kalanına) doğru şekilde genelleşiyor mu.
"""

import numpy as np

from packages.color_engine.calibration import get, qr_fixed_regions
from packages.qr_layout.colors import finder_pattern_reference_pixels, module_pixel_center
from packages.qr_layout.generator import generate_qr, module_matrix
from packages.qr_layout.render import render_colored_image

_SCALE = 10
_BORDER = 4


def _distort(image: np.ndarray, white_cam, black_cam) -> np.ndarray:
    """Sıcak/sarımsı ışıkta çekilmiş bir fotoğrafı simüle eden, kanal
    bazlı doğrusal (gain+ofset) bozulma — true=0 -> black_cam, true=255 -> white_cam."""
    white_cam = np.asarray(white_cam, dtype=np.float64)
    black_cam = np.asarray(black_cam, dtype=np.float64)
    normalized = image.astype(np.float64) / 255.0
    distorted = black_cam + normalized * (white_cam - black_cam)
    return np.clip(distorted, 0, 255).astype(np.uint8)


def _render_plain_qr() -> np.ndarray:
    """Sensör hücresi olmayan (nötr) bir QR'ı düz siyah/beyaz rasterize eder."""
    qr = generate_qr("TEST-D-CALIBRATION", error="h")
    layout = {"sensor_modules": []}
    image = render_colored_image(qr, layout, state=None, scale=_SCALE, border=_BORDER)
    return np.array(image.convert("RGB"))


def test_qr_fixed_regions_corrects_finder_pattern_points():
    rendered = _render_plain_qr()
    cam_white, cam_black = (225, 215, 170), (40, 30, 15)  # sarımsı ışık kayması
    distorted = _distort(rendered, cam_white, cam_black)

    pixels = finder_pattern_reference_pixels(scale=_SCALE, border=_BORDER)
    (by, bx), (wy, wx) = pixels["black"], pixels["white"]
    references = {"black": tuple(distorted[by, bx]), "white": tuple(distorted[wy, wx])}

    corrected = qr_fixed_regions(distorted, references)

    assert np.allclose(corrected[by, bx].astype(np.float64), [0, 0, 0], atol=2)
    assert np.allclose(corrected[wy, wx].astype(np.float64), [255, 255, 255], atol=2)


def test_qr_fixed_regions_generalizes_to_untouched_module():
    """Referans olarak hiç kullanılmamış, görüntünün başka bir yerindeki
    bir modül de (bit'ine göre) doğru gerçek renge dönmeli — kalibrasyonun
    yalnızca örneklenen iki noktada değil, TÜM görüntüde işe yaradığını
    kanıtlar."""
    rendered = _render_plain_qr()
    cam_white, cam_black = (225, 215, 170), (40, 30, 15)
    distorted = _distort(rendered, cam_white, cam_black)

    pixels = finder_pattern_reference_pixels(scale=_SCALE, border=_BORDER)
    (by, bx), (wy, wx) = pixels["black"], pixels["white"]
    references = {"black": tuple(distorted[by, bx]), "white": tuple(distorted[wy, wx])}

    corrected = qr_fixed_regions(distorted, references)

    qr = generate_qr("TEST-D-CALIBRATION", error="h")
    matrix = module_matrix(qr)
    n = len(matrix)
    test_row, test_col = n // 2, n // 2  # finder pattern'lerden uzak, merkezi bir modül
    bit = matrix[test_row][test_col]
    expected = (0, 0, 0) if bit else (255, 255, 255)

    ty, tx = module_pixel_center(test_row, test_col, scale=_SCALE, border=_BORDER)
    assert np.allclose(corrected[ty, tx].astype(np.float64), expected, atol=2)


def test_qr_fixed_regions_is_same_math_as_white_black():
    """D, A ile matematiksel olarak aynı düzeltmeyi uygulamalı — fark
    yalnızca referans renklerin kaynağı (QR'ın kendi modülleri vs. ayrı
    bir baskı yaması), düzeltme formülü değil."""
    image = np.array([[[130, 90, 60]]], dtype=np.uint8)
    references = {"white": (220, 200, 180), "black": (30, 25, 15)}

    from packages.color_engine.calibration import white_black

    assert np.array_equal(qr_fixed_regions(image, references), white_black(image, references))


def test_get_returns_qr_fixed_regions_implementation():
    assert get("qr_fixed_regions") is qr_fixed_regions
