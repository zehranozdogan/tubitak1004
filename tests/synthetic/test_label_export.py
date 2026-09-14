"""export_label: aynı layout_version -> aynı reaktif yerleşim (§5.2/7),
farklı payload (ör. parti no) -> farklı QR deseni."""

from packages.label_export import build_label_payload, export_label
from packages.qr_layout import module_matrix, seed_from_layout_version


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
