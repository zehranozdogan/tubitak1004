"""DEMO_QR_STATE_COLORS_v1 profilinin qr_layout.colors.STATE_COLORS ile
senkron kaldığını doğrular — biri değişip diğeri unutulursa test kırılır.
"""

import pytest

from packages.color_engine.colorspace import rgb_to_lab
from packages.color_engine.types import Rgb
from packages.profile_schema.loader import EXAMPLES_DIR, load_sensor_profile
from packages.qr_layout.colors import STATE_COLORS

_PROFILE_PATH = EXAMPLES_DIR / "DEMO_QR_STATE_COLORS_v1.sensor_profile.json"


def _load() -> dict:
    return load_sensor_profile(_PROFILE_PATH)


def test_schema_validates():
    profile = _load()
    assert profile["profile_id"] == "DEMO_QR_STATE_COLORS_v1"
    assert profile["class_thresholds"] is not None


def test_every_state_and_tone_from_state_colors_is_present():
    profile = _load()
    present = {(p["state"], tuple(p["rgb"])) for p in profile["scale_points"]}

    for state, tones in STATE_COLORS.items():
        for rgb in tones.values():
            assert (state, tuple(rgb)) in present, f"{state}/{rgb} profilde eksik"


def test_lab_values_match_rgb_to_lab_conversion():
    profile = _load()
    for point in profile["scale_points"]:
        expected = rgb_to_lab(Rgb(*point["rgb"]))
        assert point["lab"][0] == pytest.approx(expected.L, abs=0.05)
        assert point["lab"][1] == pytest.approx(expected.a, abs=0.05)
        assert point["lab"][2] == pytest.approx(expected.b, abs=0.05)
