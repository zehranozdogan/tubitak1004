"""white_black() kalibrasyon yöntemi testleri (rapor §6.1 A)."""

import numpy as np

from packages.color_engine.calibration import get, white_black


def test_white_black_maps_references_to_extremes():
    white_ref = (200, 190, 210)
    black_ref = (30, 40, 20)
    image = np.array([[white_ref, black_ref]], dtype=np.uint8)  # 1x2 piksel

    corrected = white_black(image, {"white": white_ref, "black": black_ref})

    assert np.allclose(corrected[0, 0], [255, 255, 255], atol=2)
    assert np.allclose(corrected[0, 1], [0, 0, 0], atol=2)


def test_white_black_removes_channel_dependent_color_cast():
    """Kamera her kanalı farklı kazanç/ofsetle çekse bile (renk sıcaklığı
    kayması), aynı referans noktalarından türetilen düzeltme gerçek nötr
    gri değeri geri getirmeli."""
    white_cam = np.array([180, 200, 220], dtype=np.float64)
    black_cam = np.array([10, 20, 30], dtype=np.float64)
    true_gray = 128.0

    # Kameranın gerçek sahneye uyguladığı varsayılan doğrusal bozulma.
    captured = black_cam + (true_gray / 255.0) * (white_cam - black_cam)
    image = np.array([[captured]], dtype=np.uint8)  # 1x1 piksel

    corrected = white_black(image, {"white": tuple(white_cam), "black": tuple(black_cam)})

    assert np.allclose(corrected[0, 0].astype(np.float64), [128, 128, 128], atol=2)


def test_white_black_clips_out_of_reference_range():
    image = np.array([[[255, 255, 255]]], dtype=np.uint8)

    corrected = white_black(image, {"white": (200, 200, 200), "black": (50, 50, 50)})

    assert corrected.max() <= 255
    assert corrected.min() >= 0


def test_white_black_handles_degenerate_reference_channel():
    """Bir kanalda white == black (dejenere referans) çökmemeli / NaN üretmemeli."""
    image = np.array([[[128, 128, 128]]], dtype=np.uint8)

    corrected = white_black(image, {"white": (200, 200, 200), "black": (200, 50, 50)})

    assert np.isfinite(corrected).all()


def test_get_returns_white_black_implementation():
    assert get("white_black") is white_black
