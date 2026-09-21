"""Etiket kenarı referans yaması — rapor §5.2/5'in "QR içinde VEYA etiket
kenarında" alternatiflerinden ikincisi. QR-içi (finder pattern) yöntemi
zaten test_qr_layout.py'de doğrulanıyor; bu dosya YENİ (edge-patch) yolu
doğrular.
"""

from __future__ import annotations

import json

import pytest

from packages.qr_layout import build_layout, generate_qr, reactive_candidates, select_reactive_modules
from packages.qr_layout.colors import EDGE_PATCH_MARGIN, GRAY_REFERENCE_RGB, module_pixel_center
from packages.qr_layout.render import render_colored_image, render_with_edge_gray_patch

cv2 = pytest.importorskip("cv2", reason="opencv-python-headless kurulu değil")
from packages.qr_layout.decode import decode_qr_image  # noqa: E402

PAYLOAD = {
    "product_id": "TR-EDGE-TEST",
    "product_type": "LEVREK",
    "production_date": "2026-09-17",
    "sensor_profile_id": "GENIPIN_PUTRESIN_v2",
    "layout_version": "QR_SENSOR_v4",
}
PAYLOAD_TEXT = json.dumps(PAYLOAD, ensure_ascii=False, separators=(",", ":"))


def _qr_and_layout():
    qr = generate_qr(PAYLOAD_TEXT, error="h")
    modules = select_reactive_modules(reactive_candidates(qr), density="high", seed=1)
    layout = build_layout(qr, modules, layout_version=PAYLOAD["layout_version"], density="high")
    return qr, layout


def test_edge_patch_renders_at_recorded_position_with_true_gray():
    qr, layout = _qr_and_layout()
    scale, border = 10, 4
    img, (row, col) = render_with_edge_gray_patch(qr, layout, state="fresh", scale=scale, border=border)

    total_border = border + EDGE_PATCH_MARGIN
    cy, cx = module_pixel_center(row, col, scale=scale, border=total_border)
    assert img.getpixel((cx, cy)) == GRAY_REFERENCE_RGB


def test_edge_patch_does_not_touch_required_quiet_zone():
    """Yama, QR'ın hemen etrafındaki ZORUNLU quiet zone'a (rapor §5.1)
    taşmamalı — o bölge hâlâ tamamen beyaz kalmalı."""
    qr, layout = _qr_and_layout()
    scale, border = 10, 4
    img, _ = render_with_edge_gray_patch(qr, layout, state="fresh", scale=scale, border=border)

    total_border = border + EDGE_PATCH_MARGIN
    n = len(qr.matrix)
    # QR'a en yakın quiet-zone satırı (yama şeridinden ayrı, gerçek border içinde)
    y = (total_border - 1) * scale + scale // 2
    x = (total_border + n // 2) * scale + scale // 2
    assert img.getpixel((x, y)) == (255, 255, 255)


def test_edge_patch_image_still_decodes():
    """Ek yama ve büyümüş kenar boşluğu, QR'ın kendisini bozmamalı."""
    qr, layout = _qr_and_layout()
    img, _ = render_with_edge_gray_patch(qr, layout, state="spoiled", scale=10, border=4)
    decoded = decode_qr_image(img)
    assert decoded is not None
    assert json.loads(decoded) == PAYLOAD


def test_edge_patch_image_matches_plain_render_for_qr_region():
    """Yamalı render, QR'ın kendisi için sıradan render_colored_image ile
    AYNI pikselleri üretmeli — yalnızca kenar boşluğu ve yama eklenmiş olmalı."""
    qr, layout = _qr_and_layout()
    scale, border = 10, 4
    plain = render_colored_image(qr, layout, state="fresh", scale=scale, border=border)
    with_patch, _ = render_with_edge_gray_patch(qr, layout, state="fresh", scale=scale, border=border)

    offset = EDGE_PATCH_MARGIN * scale
    n = len(qr.matrix)
    qr_px = (n + 2 * border) * scale
    cropped = with_patch.crop((offset, offset, offset + qr_px, offset + qr_px))
    assert list(cropped.getdata()) == list(plain.getdata())
