"""quality_score() gerçek görüntü kalitesi testleri (rapor §7.1)."""

import cv2
import numpy as np

from packages.color_engine.quality import quality_score, should_rescan


def _checkerboard(size: int = 200, square: int = 4) -> np.ndarray:
    """Yüksek frekanslı desen: keskin/net, orta parlaklıkta bir görüntüyü simüle eder."""
    tile = np.indices((size, size)).sum(axis=0) // square % 2
    return (tile * 155 + 60).astype(np.uint8)  # ~60..215 arası: aşırı parlama/karanlık yok


def _blur(gray: np.ndarray, ksize: int = 25) -> np.ndarray:
    return cv2.GaussianBlur(gray, (ksize, ksize), 0)


def test_sharp_image_scores_higher_than_blurry():
    sharp = _checkerboard()
    blurry = _blur(sharp)

    assert quality_score(sharp) > quality_score(blurry)


def test_overexposed_image_scores_low():
    overexposed = np.full((200, 200), 255, dtype=np.uint8)

    assert quality_score(overexposed) < 0.5


def test_too_dark_image_scores_low():
    dark = np.full((200, 200), 5, dtype=np.uint8)

    assert quality_score(dark) < 0.5


def test_score_is_bounded_between_zero_and_one():
    images = (_checkerboard(), np.full((50, 50), 255, dtype=np.uint8), np.zeros((50, 50), dtype=np.uint8))
    for image in images:
        assert 0.0 <= quality_score(image) <= 1.0


def test_should_rescan_uses_real_score_for_bad_image():
    overexposed = np.full((200, 200), 255, dtype=np.uint8)

    assert should_rescan(quality_score(overexposed)) is True


def test_should_rescan_accepts_good_image():
    sharp = _checkerboard()

    assert should_rescan(quality_score(sharp)) is False
