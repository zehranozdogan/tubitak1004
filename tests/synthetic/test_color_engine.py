"""color_engine iskelet sözleşmesi (rapor §10.2 / §7.2)."""

from packages.color_engine import analyze, should_rescan
from packages.color_engine.types import ColorEngineResult


def test_analyze_returns_rescan_placeholder():
    sensor_profile = {
        "profile_id": "GENIPIN_PUTRESIN_v2",
        "class_thresholds": None,
        "quality_gate": {"min_quality_score": 0.5},
    }
    layout_version = {"layout_version": "QR_SENSOR_v4"}
    result = analyze(object(), sensor_profile, layout_version)

    assert isinstance(result, ColorEngineResult)
    assert result.rescan_recommended is True
    assert result.freshness_class is None        # eşik yok -> sınıf yok
    assert result.notes


def test_should_rescan_threshold():
    assert should_rescan(0.30, 0.5) is True
    assert should_rescan(0.70, 0.5) is False
