"""warp_to_canonical() testleri (rapor §6.2 adım 2).

Senaryo: temiz (cepheden) render edilmiş bir QR'ı yapay bir perspektifle
("açılı fotoğraf" simülasyonu) bozup, gerçek QR-köşe-tespiti +
warp_to_canonical ile geri düzleştiriyoruz. Asıl önemli olan, ham
piksel farkı değil — MODÜL MERKEZLERİNDEKİ doğruluk (renk örnekleme tam
oradan yapılacak); kenarlardaki enterpolasyon bulanıklığı önemsiz.
"""

import io

import numpy as np
import cv2
import pytest
from PIL import Image

from packages.color_engine.homography import canonical_size, warp_to_canonical
from packages.qr_layout.colors import module_pixel_center
from packages.qr_layout.decode import decode_qr_image_with_corners
from packages.qr_layout.generator import generate_qr
from packages.qr_layout.render import png_bytes

_SCALE = 10
_BORDER = 4


def _ground_truth_and_matrix_size(payload: str) -> tuple[np.ndarray, int]:
    qr = generate_qr(payload, error="h")
    n = qr.version * 4 + 17
    image = Image.open(io.BytesIO(png_bytes(qr, scale=_SCALE, border=_BORDER))).convert("RGB")
    return np.array(image), n


def _simulate_angled_photo(ground_truth: np.ndarray) -> np.ndarray:
    """Aşağıdan yukarı bakan açılı bir çekimi taklit eden perspektif bozulma."""
    size = ground_truth.shape[0]
    src = np.array([[0, 0], [size, 0], [size, size], [0, size]], dtype=np.float32)
    dst = np.array(
        [
            [size * 0.15, size * 0.05],
            [size * 0.85, size * 0.05],
            [size * 0.98, size * 0.95],
            [size * 0.02, size * 0.95],
        ],
        dtype=np.float32,
    )
    transform = cv2.getPerspectiveTransform(src, dst)
    return cv2.warpPerspective(ground_truth, transform, (size, size), borderValue=(200, 200, 200))


def test_warp_recovers_exact_colors_at_module_centers():
    ground_truth, n = _ground_truth_and_matrix_size("TEST-HOMOGRAPHY-1")
    photo = _simulate_angled_photo(ground_truth)

    text, corners = decode_qr_image_with_corners(photo)
    assert text == "TEST-HOMOGRAPHY-1"

    recovered = warp_to_canonical(photo, corners, matrix_size=n, scale=_SCALE, border=_BORDER)

    max_errors = []
    for r in range(n):
        for c in range(n):
            y, x = module_pixel_center(r, c, scale=_SCALE, border=_BORDER)
            max_errors.append(
                int(np.abs(ground_truth[y, x].astype(int) - recovered[y, x].astype(int)).max())
            )

    max_errors = np.array(max_errors)
    # Enterpolasyon/yuvarlama payı için küçük bir tolerans; asıl beklenti
    # neredeyse tüm modüllerin (bit sınıfını bozmayacak ölçüde) doğru
    # kurtarılması.
    assert (max_errors > 30).mean() < 0.02
    assert max_errors.mean() < 3.0


def test_canonical_size_matches_warped_output_shape():
    ground_truth, n = _ground_truth_and_matrix_size("TEST-HOMOGRAPHY-2")
    photo = _simulate_angled_photo(ground_truth)
    _text, corners = decode_qr_image_with_corners(photo)

    recovered = warp_to_canonical(photo, corners, matrix_size=n, scale=_SCALE, border=_BORDER)

    expected = canonical_size(n, scale=_SCALE, border=_BORDER)
    assert recovered.shape[:2] == (expected, expected)


def test_warp_fails_gracefully_without_four_corners():
    image = np.zeros((100, 100, 3), dtype=np.uint8)
    with pytest.raises((ValueError, cv2.error)):
        warp_to_canonical(image, None, matrix_size=25)
