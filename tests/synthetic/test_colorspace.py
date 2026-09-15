"""RGB<->Lab ve ΔE (CIEDE2000) testleri (rapor §6.2 adım 6)."""

import pytest

from packages.color_engine.colorspace import delta_e, rgb_to_lab
from packages.color_engine.types import Lab, Rgb


def test_delta_e_identical_colors_is_zero():
    lab = Lab(L=50.0, a=10.0, b=-5.0)

    assert delta_e(lab, lab) == pytest.approx(0.0, abs=1e-6)


def test_delta_e_is_symmetric():
    a = Lab(L=40.0, a=20.0, b=10.0)
    b = Lab(L=60.0, a=-10.0, b=30.0)

    assert delta_e(a, b) == pytest.approx(delta_e(b, a), abs=1e-9)


def test_delta_e_increases_with_lightness_difference():
    base = Lab(L=50.0, a=0.0, b=0.0)
    near = Lab(L=55.0, a=0.0, b=0.0)
    far = Lab(L=80.0, a=0.0, b=0.0)

    assert delta_e(base, near) < delta_e(base, far)


def test_rgb_to_lab_white_and_black_anchors():
    white = rgb_to_lab(Rgb(255, 255, 255))
    black = rgb_to_lab(Rgb(0, 0, 0))

    assert white.L == pytest.approx(100.0, abs=0.5)
    assert abs(white.a) < 1.0
    assert abs(white.b) < 1.0
    assert black.L == pytest.approx(0.0, abs=0.5)


def test_near_white_grays_are_closer_than_black_and_white():
    """Beyaza yakın bir gri ile beyaz arasındaki fark, beyaz-siyah
    farkından çok daha küçük olmalı — temel tutarlılık kontrolü."""
    white = rgb_to_lab(Rgb(255, 255, 255))
    near_white = rgb_to_lab(Rgb(245, 245, 245))
    black = rgb_to_lab(Rgb(0, 0, 0))

    assert delta_e(white, near_white) < delta_e(white, black)
