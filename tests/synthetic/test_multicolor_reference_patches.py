"""Çoklu renk referans yaması — rapor §6.1 C: "3x3/çok renkli düzeltme
matrisi" (`calibration.multicolor_patch`, >=4 nokta gerektirir). Tek gri
yamanın (§6.1 B) doğrulaması test_edge_reference_patch.py'de; bu dosya
ÇOKLU/farklı renk yolunu doğrular.
"""

from __future__ import annotations

import json

import pytest

from packages.qr_layout import build_layout, generate_qr, reactive_candidates, select_reactive_modules
from packages.qr_layout.colors import EDGE_PATCH_MARGIN, EDGE_REFERENCE_COLORS, module_pixel_center
from packages.qr_layout.render import render_colored_image, render_with_edge_reference_patches

cv2 = pytest.importorskip("cv2", reason="opencv-python-headless kurulu değil")
from packages.qr_layout.decode import decode_qr_image  # noqa: E402

PAYLOAD = {
    "product_id": "TR-MULTICOLOR-TEST",
    "product_type": "LEVREK",
    "production_date": "2026-09-17",
    "sensor_profile_id": "GENIPIN_PUTRESIN_v2",
    "layout_version": "QR_SENSOR_v4",
}
PAYLOAD_TEXT = json.dumps(PAYLOAD, ensure_ascii=False, separators=(",", ":"))


def _qr_and_layout():
    qr = generate_qr(PAYLOAD_TEXT, error="h")
    modules = select_reactive_modules(reactive_candidates(qr), density="medium", seed=1)
    layout = build_layout(qr, modules, layout_version=PAYLOAD["layout_version"], density="medium")
    return qr, layout


def test_all_patches_render_at_distinct_non_overlapping_positions():
    qr, layout = _qr_and_layout()
    scale, border = 14, 4
    img, positions = render_with_edge_reference_patches(qr, layout, state="fresh", scale=scale, border=border)

    assert set(positions) == set(EDGE_REFERENCE_COLORS)
    cols = sorted(c for _, c in positions.values())
    assert all(b - a >= 3 for a, b in zip(cols, cols[1:])), "yamalar çakışmamalı"

    total_border = border + EDGE_PATCH_MARGIN
    for name, (row, col) in positions.items():
        cy, cx = module_pixel_center(row, col, scale=scale, border=total_border)
        assert img.getpixel((cx, cy)) == EDGE_REFERENCE_COLORS[name]


def test_multicolor_patches_do_not_touch_quiet_zone_or_qr():
    qr, layout = _qr_and_layout()
    scale, border = 14, 4
    img, _ = render_with_edge_reference_patches(qr, layout, state="fresh", scale=scale, border=border)
    plain = render_colored_image(qr, layout, state="fresh", scale=scale, border=border)

    n = len(qr.matrix)
    offset = EDGE_PATCH_MARGIN * scale
    qr_px = (n + 2 * border) * scale
    cropped = img.crop((offset, offset, offset + qr_px, offset + qr_px))
    assert list(cropped.getdata()) == list(plain.getdata())


def test_multicolor_patch_image_still_decodes():
    qr, layout = _qr_and_layout()
    img, _ = render_with_edge_reference_patches(qr, layout, state="spoiled", scale=14, border=4)
    decoded = decode_qr_image(img)
    assert decoded is not None
    assert json.loads(decoded) == PAYLOAD


def test_custom_color_set_is_respected():
    """Farklı bir renk seti (ör. yalnızca 4 nokta) verilirse onunla çalışmalı."""
    qr, layout = _qr_and_layout()
    custom = {"white_ref": (255, 255, 255), "black_ref": (0, 0, 0), "mid": (128, 128, 128), "warm": (200, 120, 40)}
    scale, border = 14, 4
    img, positions = render_with_edge_reference_patches(
        qr, layout, state="fresh", scale=scale, border=border, colors=custom
    )
    assert set(positions) == set(custom)
    total_border = border + EDGE_PATCH_MARGIN
    for name, (row, col) in positions.items():
        cy, cx = module_pixel_center(row, col, scale=scale, border=total_border)
        assert img.getpixel((cx, cy)) == custom[name]
