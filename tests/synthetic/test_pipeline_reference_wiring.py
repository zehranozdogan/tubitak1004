"""pipeline.analyze() artık B (white_gray_black) ve C (multicolor_patch)
kalibrasyon yöntemlerini GERÇEKTEN kullanıyor mu — üretici tarafı
(qr_layout/render.py::render_label_image, label_export/export.py) bu
referans yamalarını zaten basıyordu; bu dosya OKUYUCU tarafının artık
onları görmezden gelmediğini doğrular (20 Eylül'de düzeltildi).
"""

from __future__ import annotations

import tempfile

import numpy as np
import pytest

cv2 = pytest.importorskip("cv2", reason="opencv-python-headless kurulu değil")

from packages.color_engine import analyze  # noqa: E402
from packages.label_export import build_label_payload, export_label  # noqa: E402
from packages.qr_layout import build_layout, generate_qr, reactive_candidates, select_reactive_modules  # noqa: E402
from packages.qr_layout.render import render_colored_image  # noqa: E402


def _fake_photo(pil_image):
    """Hafif açı + ışık kayması — devrim'in test_color_engine.py'deki
    _render_photo'suyla aynı fikir, bu dosyada bağımsız kopyası."""
    rgb = np.array(pil_image.convert("RGB"))[:, :, ::-1]
    size = rgb.shape[0]
    src = np.array([[0, 0], [size, 0], [size, size], [0, size]], dtype=np.float32)
    dst = np.array(
        [[size * 0.05, size * 0.03], [size * 0.95, size * 0.03],
         [size * 0.97, size * 0.97], [size * 0.03, size * 0.97]],
        dtype=np.float32,
    )
    transform = cv2.getPerspectiveTransform(src, dst)
    photo = cv2.warpPerspective(rgb, transform, (size, size), borderValue=(180, 180, 180)).astype(np.float64)
    photo = np.clip(photo * [1.05, 0.95, 1.1], 0, 255).astype(np.uint8)
    return photo


def _profile(code: str) -> dict:
    return {
        "scale_points": [{"value": 0.0, "lab": [50.0, 5.0, 5.0], "state": "fresh"}],
        "class_thresholds": None,
        "calibration_method": {"code": code},
        "quality_gate": {"min_quality_score": 0.5},
    }


@pytest.mark.parametrize("code", ["white_black", "white_gray_black", "multicolor_patch"])
def test_analyze_uses_producer_reference_patches_without_falling_back(code, tmp_path):
    """export_label() ile GERÇEKTEN üretilen bir etiketi analyze() ile
    okuyunca, hiçbir B/C fallback notu OLMAMALI — üretici bastığı referansı
    okuyucu gerçekten kullanmalı."""
    payload = build_label_payload("TR-WIRING", "LEVREK", "2026-09-20", "GENIPIN_PUTRESIN_v2", "QR_SENSOR_v4")
    profile = _profile(code)

    result = export_label(payload, tmp_path, density="low", sensor_profile=profile)

    from PIL import Image

    img = Image.open(result["paths"]["state_fresh"])
    photo = _fake_photo(img)

    out = analyze(photo, profile, result["layout"])

    assert out.rescan_recommended is False
    assert not any("düşüldü" in note for note in out.notes), out.notes


def test_analyze_falls_back_gracefully_when_gray_reference_missing():
    """B seçilmiş ama layout'ta 'gray' hiç yoksa (eski/elle kurulmuş
    layout) — çökmemeli, white_black'e düşüp SESSİZCE DEĞİL notta açıklamalı."""
    qr = generate_qr("payload-wiring-1", error="h")
    modules = select_reactive_modules(reactive_candidates(qr), density="low", seed=1)
    layout = build_layout(qr, modules, layout_version="QR_TEST", density="low")
    assert "gray" not in layout["reference_regions"]  # varsayım: yalnızca finder white/black var

    profile = _profile("white_gray_black")
    image = render_colored_image(qr, layout, state="fresh", scale=10, border=4)
    bgr = np.array(image.convert("RGB"))[:, :, ::-1]

    out = analyze(bgr, profile, layout)

    assert out.rescan_recommended is False
    assert any("gray" in note and "düşüldü" in note for note in out.notes)


def test_analyze_falls_back_gracefully_when_multicolor_points_insufficient():
    """C seçilmiş ama layout'ta yeterli (>=4) referans noktası yoksa —
    çökmemeli, white_black'e düşüp notta AÇIKÇA kaç nokta bulunduğunu söylemeli."""
    qr = generate_qr("payload-wiring-2", error="h")
    modules = select_reactive_modules(reactive_candidates(qr), density="low", seed=1)
    layout = build_layout(qr, modules, layout_version="QR_TEST", density="low")

    profile = _profile("multicolor_patch")
    image = render_colored_image(qr, layout, state="fresh", scale=10, border=4)
    bgr = np.array(image.convert("RGB"))[:, :, ::-1]

    out = analyze(bgr, profile, layout)

    assert out.rescan_recommended is False
    assert any("2 bulundu" in note for note in out.notes)
