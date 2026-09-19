"""color_engine.pipeline.analyze() uçtan uca testleri (rapor §6.2, §7.2)."""

import cv2
import numpy as np

from packages.color_engine import analyze, should_rescan
from packages.color_engine.colorspace import rgb_to_lab
from packages.color_engine.types import ColorEngineResult, Rgb
from packages.qr_layout.colors import STATE_COLORS
from packages.qr_layout.generator import generate_qr, reactive_candidates
from packages.qr_layout.render import render_colored_image

_SCALE, _BORDER = 10, 4


def _render_photo(payload: str, state: str, *, n_sensor_modules: int = 8):
    """Bir durumla render edilmiş QR'ı açılı+renk kaymalı sahte bir
    fotoğrafa dönüştürür (BGR, pipeline'ın beklediği sözleşme)."""
    qr = generate_qr(payload, error="h")
    n = qr.version * 4 + 17
    sensor_modules = reactive_candidates(qr)[:n_sensor_modules]
    layout = {"matrix_size": n, "sensor_modules": [list(m) for m in sensor_modules]}

    image = render_colored_image(qr, layout, state=state, scale=_SCALE, border=_BORDER)
    rgb = np.array(image.convert("RGB"))[:, :, ::-1]  # RGB -> BGR
    size = rgb.shape[0]

    src = np.array([[0, 0], [size, 0], [size, size], [0, size]], dtype=np.float32)
    dst = np.array(
        [
            [size * 0.1, size * 0.05],
            [size * 0.9, size * 0.05],
            [size * 0.97, size * 0.95],
            [size * 0.03, size * 0.95],
        ],
        dtype=np.float32,
    )
    transform = cv2.getPerspectiveTransform(src, dst)
    photo = cv2.warpPerspective(rgb, transform, (size, size), borderValue=(180, 180, 180))
    photo = np.clip(photo.astype(np.float64) * [1.05, 0.95, 1.1], 0, 255).astype(np.uint8)  # ışık kayması

    return photo, layout


def _profile_for_state(state: str, *, with_thresholds: bool) -> dict:
    dark_lab = rgb_to_lab(Rgb(*STATE_COLORS[state]["dark"]))
    other_state = "spoiled" if state != "spoiled" else "fresh"
    other_lab = rgb_to_lab(Rgb(*STATE_COLORS[other_state]["dark"]))
    return {
        "scale_points": [
            {"value": 0.0, "lab": [dark_lab.L, dark_lab.a, dark_lab.b], "state": state},
            {"value": 1.0, "lab": [other_lab.L, other_lab.a, other_lab.b], "state": other_state},
        ],
        "class_thresholds": {"note": "test"} if with_thresholds else None,
        "calibration_method": {"code": "white_black"},
        "quality_gate": {"min_quality_score": 0.5},
    }


def test_analyze_end_to_end_matches_true_state_through_angle_and_color_cast():
    """Açılı + ışık kaymalı sahte bir fotoğraftan uçtan uca doğru tazelik
    sonucunu (homografi + kalibrasyon + ROI + ΔE eşleştirme) üretmeli."""
    photo, layout = _render_photo("TEST-PIPELINE-1", "fresh")
    profile = _profile_for_state("fresh", with_thresholds=True)

    result = analyze(photo, profile, layout)

    assert isinstance(result, ColorEngineResult)
    assert result.rescan_recommended is False
    assert result.freshness_class == "fresh"
    # ΔE eşiği gevşek tutuluyor: STATE_COLORS artık gerçek Putresin verisine
    # dayalı (2026-09-18), eski parlak demo renklerden çok daha düşük
    # kontrastlı — aynı mutlak piksel hatası (homografi/ışık kayması
    # kalıntısı) bu dar aralıkta orantısız büyük bir ΔE'ye dönüşüyor. Asıl
    # kritik doğrulama zaten yukarıda: doğru SINIF (fresh) bulunuyor mu.
    assert result.delta_e is not None and result.delta_e < 15.0
    assert len(result.module_readings) == 8


def test_analyze_freshness_class_none_without_class_thresholds():
    """§7.2 kritik kural: eşleşme doğru olsa bile class_thresholds yoksa
    freshness_class None kalmalı, technical_level dolu olmalı."""
    photo, layout = _render_photo("TEST-PIPELINE-2", "fresh")
    profile = _profile_for_state("fresh", with_thresholds=False)

    result = analyze(photo, profile, layout)

    assert result.freshness_class is None
    assert result.technical_level


def test_analyze_recommends_rescan_on_low_quality_image():
    blank = np.full((150, 150, 3), 255, dtype=np.uint8)
    profile = _profile_for_state("fresh", with_thresholds=False)
    layout = {"matrix_size": 25, "sensor_modules": [[10, 10]]}

    result = analyze(blank, profile, layout)

    assert result.rescan_recommended is True
    assert result.freshness_class is None
    assert result.technical_level is None
    assert result.notes


def test_analyze_recommends_rescan_when_no_qr_detected():
    rng = np.random.default_rng(0)
    noise = rng.integers(80, 180, size=(150, 150, 3)).astype(np.uint8)
    profile = _profile_for_state("fresh", with_thresholds=False)
    layout = {"matrix_size": 25, "sensor_modules": [[10, 10]]}

    result = analyze(noise, profile, layout)

    assert result.rescan_recommended is True


def test_analyze_falls_back_to_white_black_for_unsupported_calibration_method():
    """multicolor_patch DESTEKLENİYOR (bkz. test_pipeline_reference_
    wiring.py) ama bu testteki layout'ta (elle kurulmuş, reference_regions
    hiç yok) gerekli >=4 noktayı sağlayamıyor; çökmek yerine white_black'e
    düşüp notta bunu açıklamalı."""
    photo, layout = _render_photo("TEST-PIPELINE-3", "fresh", n_sensor_modules=5)
    profile = _profile_for_state("fresh", with_thresholds=False)
    profile["calibration_method"] = {"code": "multicolor_patch"}

    result = analyze(photo, profile, layout)

    assert result.rescan_recommended is False
    assert any("white_black" in note for note in result.notes)


def test_should_rescan_threshold():
    assert should_rescan(0.30, 0.5) is True
    assert should_rescan(0.70, 0.5) is False
