"""QR gerçekten okunabiliyor mu? (rapor §11 Aşama A — sanal QR dayanıklılık testi)

Reaktif hücrelerin renklendirilmesi, QR'ın kendi decode edilebilirliğini
bozmamalı (§5.2). Şimdiye kadar bu yalnızca gözle kontrol edilmişti; bu test
gerçek bir QR decoder (OpenCV) ile üç yoğunluk × dört durumun tamamını
doğrular.
"""

from __future__ import annotations

import json

import pytest

from packages.qr_layout import (
    build_layout,
    generate_qr,
    reactive_candidates,
    select_reactive_modules,
)
from packages.qr_layout.decode import decode_qr_image
from packages.qr_layout.render import render_colored_image

cv2 = pytest.importorskip("cv2", reason="opencv-python-headless kurulu değil")

PAYLOAD = {
    "product_id": "TR-DECODE-TEST",
    "product_type": "LEVREK",
    "production_date": "2026-09-14",
    "sensor_profile_id": "GENIPIN_PUTRESIN_v2",
    "layout_version": "QR_SENSOR_v4",
}
PAYLOAD_TEXT = json.dumps(PAYLOAD, ensure_ascii=False, separators=(",", ":"))


@pytest.mark.parametrize("density", ["low", "medium", "high"])
@pytest.mark.parametrize("state", [None, "fresh", "transition", "spoiled"])
def test_colored_qr_still_decodes(density, state):
    qr = generate_qr(PAYLOAD_TEXT, error="h")
    modules = select_reactive_modules(reactive_candidates(qr), density=density, seed=1)
    layout = build_layout(qr, modules, layout_version=PAYLOAD["layout_version"], density=density)

    image = render_colored_image(qr, layout, state=state, scale=10, border=4)
    decoded = decode_qr_image(image)

    assert decoded is not None, f"density={density} state={state}: QR okunamadı"
    assert json.loads(decoded) == PAYLOAD


def test_plain_qr_decodes_too():
    """Reaktif hücre olmadan (düz siyah/beyaz) da temel kontrol."""
    qr = generate_qr(PAYLOAD_TEXT, error="h")
    layout = build_layout(qr, [], layout_version=PAYLOAD["layout_version"], density="low")
    image = render_colored_image(qr, layout, state=None, scale=10, border=4)
    decoded = decode_qr_image(image)
    assert decoded is not None
    assert json.loads(decoded) == PAYLOAD
