"""Işık düzensizliği için LAYOUT-FARKINDA sinyal (rapor §6.2/§7.1, 21 Eylül).

Arka plan: `test_realistic_distortions.py::test_quality_score_does_not_
detect_uneven_lighting` bir öncekini (ham piksel kenar-örneklemesi) hem
sentetik hem GERÇEK cihaz fotoğraflarıyla test edip güvenilmez bulmuştu —
iyi/kullanılabilir gerçek fotoğrafları bile reddediyordu, çünkü QR'ın kendi
finder pattern köşe asimetrisinden ayırt edilemiyordu.

Buradaki yaklaşım farklı: TAHMİN değil, üç finder köşesindeki BİLİNEN AYNI
rengin (beyaz) üç farklı fiziksel konumdan ölçümü. Kasıtlı olarak SERT BİR
KAPI değil — yalnızca `confidence`'ı düşüren yumuşak bir çarpan (bkz.
pipeline.py::_reference_corner_consistency). 2 gerçek cihaz fotoğrafıyla
(tests/device/manifest.csv, ikisi de decode/ΔE açısından İYİ okumalar)
doğrulandı: rescan_rate ve delta_e bu değişiklikten ETKİLENMEDİ (hâlâ 0.0 /
25.689), yalnızca confidence hafifçe düştü (0.615 ve 0.775 çarpanlarıyla)."""

from __future__ import annotations

import cv2
import numpy as np

from packages.color_engine.colorspace import rgb_to_lab
from packages.color_engine.pipeline import analyze
from packages.color_engine.types import Rgb
from packages.qr_layout.colors import (
    FINDER_BLACK_MODULE,
    FINDER_WHITE_MODULE,
    STATE_COLORS,
    finder_pattern_corner_positions,
)
from packages.qr_layout.generator import generate_qr, reactive_candidates
from packages.qr_layout.render import render_colored_image

_SCALE, _BORDER = 10, 4


def test_finder_pattern_corner_positions_mirrors_top_left_correctly():
    """top_right/bottom_left, top_left'in (satır, sütun)'unu `matrix_size-1`
    etrafında aynalamalı — QR'ın üç finder pattern'i simetrik yerleşir
    (yalnızca sağ-alt köşede finder YOKTUR, bu QR'ın kendi tasarımı)."""
    matrix_size = 25
    positions = finder_pattern_corner_positions(matrix_size)

    assert positions["top_left"]["black"] == FINDER_BLACK_MODULE
    assert positions["top_left"]["white"] == FINDER_WHITE_MODULE

    last = matrix_size - 1
    br, bc = FINDER_BLACK_MODULE
    wr, wc = FINDER_WHITE_MODULE
    assert positions["top_right"]["black"] == (br, last - bc)
    assert positions["top_right"]["white"] == (wr, last - wc)
    assert positions["bottom_left"]["black"] == (last - br, bc)
    assert positions["bottom_left"]["white"] == (last - wr, wc)


def _build_profile(state: str, other: str) -> dict:
    dark_lab = rgb_to_lab(Rgb(*STATE_COLORS[state]["dark"]))
    other_lab = rgb_to_lab(Rgb(*STATE_COLORS[other]["dark"]))
    return {
        "scale_points": [
            {"value": 0.0, "lab": [dark_lab.L, dark_lab.a, dark_lab.b], "state": state},
            {"value": 1.0, "lab": [other_lab.L, other_lab.a, other_lab.b], "state": other},
        ],
        "class_thresholds": {"note": "test"},
        "calibration_method": {"code": "white_black"},
        "quality_gate": {"min_quality_score": 0.5},
    }


def _render_angled_photo(payload: str, state: str) -> tuple[np.ndarray, dict]:
    qr = generate_qr(payload, error="h")
    n = qr.version * 4 + 17
    sensor_modules = reactive_candidates(qr)[:8]
    layout = {"matrix_size": n, "sensor_modules": [list(m) for m in sensor_modules]}

    image = render_colored_image(qr, layout, state=state, scale=_SCALE, border=_BORDER)
    rgb = np.array(image.convert("RGB"))[:, :, ::-1]
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
    return photo, layout


def _apply_lighting_gradient(image: np.ndarray, *, low: float, high: float) -> np.ndarray:
    size = image.shape[0]
    yy, xx = np.mgrid[0:size, 0:size]
    gain = low + (high - low) * (xx + yy) / (2 * size)
    return np.clip(image.astype(np.float64) * gain[..., None], 0, 255).astype(np.uint8)


def test_confidence_drops_monotonically_with_lighting_unevenness_but_classification_survives():
    """Işık düzensizliği arttıkça confidence düzgünce düşmeli (sert bir kapı
    DEĞİL) — sınıflandırma ve rescan_recommended bundan ETKİLENMEMELİ, tıpkı
    gerçek 2 cihaz fotoğrafında görüldüğü gibi (bkz. modül docstring'i)."""
    photo, layout = _render_angled_photo("TEST-CORNER-1", "fresh")
    profile = _build_profile("fresh", "spoiled")

    baseline = analyze(photo, profile, layout)
    mild = analyze(_apply_lighting_gradient(photo, low=0.85, high=1.2), profile, layout)
    severe = analyze(_apply_lighting_gradient(photo, low=0.3, high=2.2), profile, layout)

    for result in (baseline, mild, severe):
        assert result.freshness_class == "fresh"
        assert result.rescan_recommended is False

    assert baseline.confidence > mild.confidence > severe.confidence


def test_severe_unevenness_adds_explanatory_note():
    """Belirgin köşe tutarsızlığında (confidence çarpanı < 0.85) notes'a
    AÇIKÇA yazılmalı — sessizce düşürülmemeli (rapor §7.1 dürüstlük ilkesi,
    diğer fallback notlarıyla aynı desen)."""
    photo, layout = _render_angled_photo("TEST-CORNER-2", "fresh")
    profile = _build_profile("fresh", "spoiled")

    severe = analyze(_apply_lighting_gradient(photo, low=0.3, high=2.2), profile, layout)

    assert any("Referans köşeleri" in note for note in severe.notes)
