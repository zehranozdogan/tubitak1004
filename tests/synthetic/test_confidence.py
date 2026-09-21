"""`ColorEngineResult.confidence` — reaktif modül okumalarının birbiriyle
tutarlılığına dayanan güven skoru (rapor §6.3/§10.2 output_fields).

Formülün dayanağı (uydurulmadı, ölçüldü): 64 sentetik açı×bulanıklık×
parlaklık kombinasyonunda doğru sınıflandırılan sonuçlar ort. 7.5 ΔE
sapma, yanlışlar ort. 19.3 ΔE sapma veriyordu — bkz. pipeline.py modül
başlığı ve `_SPREAD_SATURATING_DELTA_E`.
"""

from __future__ import annotations

import json

import cv2
import numpy as np
import pytest

from packages.color_engine.colorspace import rgb_to_lab
from packages.color_engine.pipeline import _module_reading_confidence, analyze
from packages.color_engine.types import Lab, ModuleReading, Rgb
from packages.qr_layout import build_layout, generate_qr, reactive_candidates, select_reactive_modules
from packages.qr_layout.colors import STATE_COLORS
from packages.qr_layout.render import render_colored_image


def _reading(lab: Lab) -> ModuleReading:
    return ModuleReading(module=(0, 0), normalized_color=Rgb(0, 0, 0), lab=lab)


def test_confidence_is_one_for_perfectly_consistent_readings():
    lab = Lab(L=50.0, a=10.0, b=10.0)
    readings = [_reading(lab) for _ in range(6)]
    assert _module_reading_confidence(readings, lab) == 1.0


def test_confidence_drops_as_readings_scatter():
    center = Lab(L=50.0, a=10.0, b=10.0)
    tight = [_reading(Lab(L=50.0 + d, a=10.0, b=10.0)) for d in (-0.5, 0.5)]
    scattered = [_reading(Lab(L=50.0 + d, a=10.0, b=10.0)) for d in (-25, 25)]

    conf_tight = _module_reading_confidence(tight, center)
    conf_scattered = _module_reading_confidence(scattered, center)

    assert conf_tight > conf_scattered
    assert 0.0 <= conf_scattered < conf_tight <= 1.0


def test_confidence_never_goes_below_zero_for_extreme_scatter():
    center = Lab(L=50.0, a=0.0, b=0.0)
    extreme = [_reading(Lab(L=0.0, a=0.0, b=0.0)), _reading(Lab(L=100.0, a=0.0, b=0.0))]
    assert _module_reading_confidence(extreme, center) == 0.0


def test_confidence_empty_readings_returns_zero():
    assert _module_reading_confidence([], Lab(L=50.0, a=0.0, b=0.0)) == 0.0


cv2_mod = pytest.importorskip("cv2", reason="opencv-python-headless kurulu değil")


def test_analyze_confidence_is_in_valid_range_end_to_end():
    """Uçtan uca (gerçek pipeline üzerinden): confidence None DEĞİL, [0,1] içinde."""
    payload = json.dumps(
        {
            "product_id": "TR-CONF", "product_type": "LEVREK", "production_date": "2026-09-18",
            "sensor_profile_id": "GENIPIN_PUTRESIN_v2", "layout_version": "QR_SENSOR_v4",
        },
        ensure_ascii=False, separators=(",", ":"),
    )
    qr = generate_qr(payload, error="h")
    modules = select_reactive_modules(reactive_candidates(qr), density="medium", seed=1)
    layout = build_layout(qr, modules, layout_version="QR_SENSOR_v4", density="medium")

    profile = {
        "scale_points": [{"value": 0.0, "lab": [50.0, 0.0, 0.0], "state": "fresh"}],
        "class_thresholds": None,
        "calibration_method": {"code": "white_black"},
        "quality_gate": {"min_quality_score": 0.5},
    }

    image = render_colored_image(qr, layout, state="fresh", scale=10, border=4)
    bgr = np.array(image.convert("RGB"))[:, :, ::-1]

    result = analyze(bgr, profile, layout)

    assert result.rescan_recommended is False
    assert result.confidence is not None
    assert 0.0 <= result.confidence <= 1.0


def test_analyze_confidence_high_for_clean_image():
    """Bozulma yok -> yüksek confidence. 21 Eylül'e kadar TAM 1.0
    beklenmiyordu (gerçek Putresin tonlarında AYNI durum içinde bile
    modüller QR bitine göre iki farklı ton — koyu/açık — gösterir,
    module_color §5.2/3, bu YAPISAL bir taban sapmasıdır). Artık bu taban
    `_SPREAD_FLOOR_DELTA_E` ile confidence'ın ÖNÜNE geçmiyor (bkz.
    pipeline.py başlığı, kullanıcı geri bildirimiyle 21 Eylül'de
    düzeltildi) — temiz bir okuma artık gerçekten ~1.0'a yakın olmalı."""
    payload = json.dumps(
        {
            "product_id": "TR-CONF2", "product_type": "LEVREK", "production_date": "2026-09-18",
            "sensor_profile_id": "GENIPIN_PUTRESIN_v2", "layout_version": "QR_SENSOR_v4",
        },
        ensure_ascii=False, separators=(",", ":"),
    )
    qr = generate_qr(payload, error="h")
    modules = select_reactive_modules(reactive_candidates(qr), density="medium", seed=1)
    layout = build_layout(qr, modules, layout_version="QR_SENSOR_v4", density="medium")
    profile = {
        "scale_points": [{"value": 0.0, "lab": [50.0, 0.0, 0.0], "state": "fresh"}],
        "class_thresholds": None,
        "calibration_method": {"code": "white_black"},
        "quality_gate": {"min_quality_score": 0.5},
    }
    image = render_colored_image(qr, layout, state="fresh", scale=10, border=4)
    bgr = np.array(image.convert("RGB"))[:, :, ::-1]

    result = analyze(bgr, profile, layout)
    assert result.confidence > 0.95


def test_confidence_reaches_near_one_below_structural_floor():
    """_module_reading_confidence birim testi: yapısal taban sapmasının
    (~3.4-4.7, module_color'un koyu/açık ikili tonundan) ALTINDAKİ bir
    sapma artık ~1.0'a yakın olmalı — eski formülde (yalnızca
    _SPREAD_SATURATING_DELTA_E'ye göre ölçekli) aynı sapma ~0.8 verirdi."""
    center = Lab(L=50.0, a=10.0, b=10.0)
    readings = [_reading(Lab(L=50.0 + d, a=10.0, b=10.0)) for d in (-2.0, 2.0)]  # ΔE ~2, tabanın altında

    assert _module_reading_confidence(readings, center) == 1.0
