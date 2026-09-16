"""match_profile_point() testleri (rapor §6.2 adım 7, §7.2 sınıf kuralı)."""

import pytest

from packages.color_engine.matching import match_profile_point
from packages.color_engine.types import Lab

_PROFILE_NO_THRESHOLDS = {
    "scale_points": [
        {"value": 0.03125, "lab": [82.5, 1.5, 6.0], "state": None},
        {"value": 0.125, "lab": [56.0, 6.0, 15.0], "state": "fresh"},
        {"value": 1.0, "lab": [21.5, 2.0, -4.0], "state": "spoiled"},
    ],
    "class_thresholds": None,
}

_PROFILE_WITH_THRESHOLDS = {
    "scale_points": _PROFILE_NO_THRESHOLDS["scale_points"],
    "class_thresholds": {"fresh_max": 0.2, "spoiled_min": 0.5},
}


def test_matches_exact_scale_point():
    measured = Lab(56.0, 6.0, 15.0)  # 0.125 noktasının aynısı

    result = match_profile_point(measured, _PROFILE_NO_THRESHOLDS)

    assert result["matched_profile_point"] == 0.125
    assert result["delta_e"] == pytest.approx(0.0, abs=1e-6)


def test_matches_nearest_scale_point_between_two():
    # 56.0 (0.125) ve 21.5 (1.0) noktaları arasında, ilkine çok daha yakın.
    measured = Lab(52.0, 5.5, 13.0)

    result = match_profile_point(measured, _PROFILE_NO_THRESHOLDS)

    assert result["matched_profile_point"] == 0.125


def test_freshness_class_is_none_without_class_thresholds():
    """§7.2 kritik kural: class_thresholds yoksa, eşleşen noktanın state'i
    dolu olsa bile freshness_class None kalmalı."""
    measured = Lab(56.0, 6.0, 15.0)  # state="fresh" olan noktayla eşleşir

    result = match_profile_point(measured, _PROFILE_NO_THRESHOLDS)

    assert result["freshness_class"] is None
    assert result["technical_level"]  # teknik seviye metni dolu olmalı


def test_freshness_class_is_set_when_class_thresholds_defined():
    measured = Lab(56.0, 6.0, 15.0)

    result = match_profile_point(measured, _PROFILE_WITH_THRESHOLDS)

    assert result["freshness_class"] == "fresh"


def test_raises_on_empty_scale_points():
    with pytest.raises(ValueError):
        match_profile_point(Lab(50.0, 0.0, 0.0), {"scale_points": [], "class_thresholds": None})


def test_matches_real_genipin_putresin_profile():
    """Gerçek örnek profil dosyasındaki değerlerle uçtan uca kontrol."""
    profile = {
        "scale_points": [
            {"value": 0.03125, "lab": [82.5, 1.5, 6.0], "state": None},
            {"value": 0.0625, "lab": [73.0, 3.5, 11.0], "state": None},
            {"value": 0.125, "lab": [56.0, 6.0, 15.0], "state": None},
            {"value": 0.25, "lab": [41.0, 7.0, 10.0], "state": None},
            {"value": 0.5, "lab": [29.5, 5.0, 3.0], "state": None},
            {"value": 1.0, "lab": [21.5, 2.0, -4.0], "state": None},
        ],
        "class_thresholds": None,
    }
    # 1.0 mM noktasına (en koyu/en "bozuk" uç) çok yakın bir ölçüm.
    measured = Lab(22.0, 2.2, -3.5)

    result = match_profile_point(measured, profile)

    assert result["matched_profile_point"] == 1.0
    assert result["freshness_class"] is None  # class_thresholds null
