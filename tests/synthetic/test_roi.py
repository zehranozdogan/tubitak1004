"""ROI örnekleme testleri (rapor §6.2 adım 4-5)."""

import numpy as np

from packages.color_engine.roi import robust_module_color, sample_module_roi
from packages.qr_layout.colors import STATE_COLORS, module_color, module_pixel_center
from packages.qr_layout.generator import generate_qr, module_matrix, reactive_candidates
from packages.qr_layout.render import render_colored_image

_SCALE, _BORDER = 10, 4


def test_robust_median_ignores_glare_outliers():
    true_color = np.array([40, 140, 60], dtype=np.uint8)
    patch = np.tile(true_color, (8, 8, 1))
    patch[0, 0] = [255, 255, 255]
    patch[0, 1] = [255, 255, 255]
    patch[7, 7] = [255, 255, 255]

    mean_color = patch.reshape(-1, 3).astype(np.float64).mean(axis=0)
    robust_color = robust_module_color(patch)

    # Naif ortalama, parlama tarafından fark edilir ölçüde saptırılıyor;
    # median tam gerçek renge dönüyor.
    assert np.abs(mean_color - true_color).max() > 5
    assert np.allclose(robust_color, true_color, atol=0.5)


def test_robust_median_ignores_shadow_outliers():
    true_color = np.array([180, 100, 90], dtype=np.uint8)
    patch = np.tile(true_color, (8, 8, 1))
    patch[3, 3] = [0, 0, 0]
    patch[3, 4] = [2, 2, 2]

    robust_color = robust_module_color(patch)

    assert np.allclose(robust_color, true_color, atol=0.5)


def test_robust_module_color_handles_fully_corrupted_patch():
    """Tüm piksel yaması aykırı (tamamen parlamış) olsa bile hata vermemeli."""
    patch = np.full((8, 8, 3), 255, dtype=np.uint8)

    color = robust_module_color(patch)

    assert color.shape == (3,)
    assert np.isfinite(color).all()


def test_sample_module_roi_matches_module_pixel_center():
    image = np.zeros((200, 200, 3), dtype=np.uint8)
    row, col, scale, border = 5, 7, 10, 4
    y, x = module_pixel_center(row, col, scale=scale, border=border)
    image[y, x] = [10, 20, 30]

    patch = sample_module_roi(image, row, col, scale=scale, border=border, margin=2)

    # Yamanın merkezi, module_pixel_center ile aynı piksele denk gelmeli.
    center = patch.shape[0] // 2
    assert list(patch[center, center]) == [10, 20, 30]


def test_roi_sampling_recovers_true_reactive_cell_color_from_rendered_qr():
    """Gerçek bir 'taze' durum QR'ı render edilip, bilinen bir reaktif
    hücrenin ROI'sinden örneklenen renk, o hücre için beklenen gerçek
    renkle (module_color) eşleşmeli."""
    qr = generate_qr("TEST-ROI", error="h")
    matrix = module_matrix(qr)
    candidates = reactive_candidates(qr)
    sensor_module = candidates[0]  # herhangi bir reaktif aday yeterli
    layout = {"sensor_modules": [list(sensor_module)]}

    image = render_colored_image(qr, layout, state="fresh", scale=_SCALE, border=_BORDER)
    array = np.array(image.convert("RGB"))

    row, col = sensor_module
    bit = matrix[row][col]
    expected = np.array(module_color(bit, is_sensor=True, state="fresh"))

    patch = sample_module_roi(array, row, col, scale=_SCALE, border=_BORDER)
    sampled = robust_module_color(patch)

    assert np.allclose(sampled, expected, atol=1.0)
