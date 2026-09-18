"""export_label: aynı layout_version -> aynı reaktif yerleşim (§5.2/7),
farklı payload (ör. parti no) -> farklı QR deseni."""

import json

import pytest

from packages.label_export import build_label_payload, export_label
from packages.profile_schema import validate
from packages.qr_layout import module_matrix, seed_from_layout_version
from packages.qr_layout.decode import decode_qr_image

cv2 = pytest.importorskip("cv2", reason="opencv-python-headless kurulu değil")


def test_seed_from_layout_version_is_deterministic():
    a = seed_from_layout_version("QR_SENSOR_v4")
    b = seed_from_layout_version("QR_SENSOR_v4")
    c = seed_from_layout_version("QR_SENSOR_v5")
    assert a == b
    assert a != c


def test_same_layout_version_gives_same_reactive_positions(tmp_path):
    p1 = build_label_payload("TR1", "LEVREK", "2026-09-10", "GENIPIN_PUTRESIN_v2", "QR_SENSOR_v4")
    p2 = build_label_payload("TR2", "LEVREK", "2026-09-10", "GENIPIN_PUTRESIN_v2", "QR_SENSOR_v4")

    r1 = export_label(p1, tmp_path, density="low")
    r2 = export_label(p2, tmp_path, density="low")

    # Parti no farklı olduğu için QR verisi (dolayısıyla modül matrisi) farklı olmalı...
    assert module_matrix(r1["qr"]) != module_matrix(r2["qr"])
    # ...ama reaktif hücre koordinatları AYNI layout_version için sabit kalmalı.
    assert r1["layout"]["sensor_modules"] == r2["layout"]["sensor_modules"]


def test_different_layout_version_gives_different_reactive_positions(tmp_path):
    p1 = build_label_payload("TR1", "LEVREK", "2026-09-10", "GENIPIN_PUTRESIN_v2", "QR_SENSOR_v4")
    p2 = build_label_payload("TR1", "LEVREK", "2026-09-10", "GENIPIN_PUTRESIN_v2", "QR_SENSOR_v5")

    r1 = export_label(p1, tmp_path, density="low")
    r2 = export_label(p2, tmp_path, density="low")

    assert r1["layout"]["sensor_modules"] != r2["layout"]["sensor_modules"]


@pytest.mark.parametrize(
    "code,expected_keys",
    [
        (None, {"white", "black"}),
        ("white_black", {"white", "black"}),
        ("white_gray_black", {"white", "black", "gray"}),
        ("multicolor_patch", {"white", "black", "gray", "red", "green", "blue"}),
    ],
)
def test_export_label_wires_calibration_reference_patches(tmp_path, code, expected_keys):
    """export_label(sensor_profile=...) — rapor §6.1 B/C artık gerçek üretim
    akışında kullanılabiliyor mu? Her kod için doğru referans yaması
    basılmalı, layout_version.json'a yazılmalı, şemayı geçmeli (negatif
    kenar-yaması koordinatları dahil) ve QR hâlâ okunmalı."""
    payload = build_label_payload("TR-CAL", "LEVREK", "2026-09-18", "GENIPIN_PUTRESIN_v2", "QR_SENSOR_v4")
    profile = {"calibration_method": {"code": code}} if code else None

    result = export_label(payload, tmp_path, density="low", sensor_profile=profile)

    assert set(result["layout"]["reference_regions"]) == expected_keys

    saved = json.loads(result["paths"]["layout_json"].read_text(encoding="utf-8"))
    validate(saved, "layout_version")  # negatif kenar-yaması koordinatları şemayı geçmeli

    from PIL import Image

    img = Image.open(result["paths"]["state_fresh"])
    decoded = decode_qr_image(img)
    assert decoded is not None
    assert json.loads(decoded) == payload


def test_export_label_without_sensor_profile_matches_old_behavior(tmp_path):
    """sensor_profile hiç verilmezse (eski çağrı biçimi) davranış AYNEN
    korunmalı — geriye dönük uyumluluk."""
    payload = build_label_payload("TR-NOPROFILE", "LEVREK", "2026-09-18", "GENIPIN_PUTRESIN_v2", "QR_SENSOR_v4")
    result = export_label(payload, tmp_path, density="low")
    assert set(result["layout"]["reference_regions"]) == {"white", "black"}
