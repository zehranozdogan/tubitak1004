"""Örnek profil / layout / payload dosyaları şemaya uygun mu?"""

from pathlib import Path

from packages.profile_schema import (
    SCHEMA_DIR,
    load_label_payload,
    load_layout_version,
    load_sensor_profile,
)

EXAMPLES = Path(__file__).resolve().parents[2] / "packages" / "profile_schema" / "examples"


def test_schema_files_exist():
    for name in ("sensor_profile", "layout_version", "label_payload"):
        assert (SCHEMA_DIR / f"{name}.schema.json").is_file()


def test_examples_load_and_cross_reference():
    profile = load_sensor_profile(EXAMPLES / "GENIPIN_PUTRESIN_v2.sensor_profile.json")
    layout = load_layout_version(EXAMPLES / "QR_SENSOR_v4.layout_version.json")
    payload = load_label_payload(EXAMPLES / "TR45678.label_payload.json")

    # Rapor §7.2: bilimsel eşik yok -> sınıf uydurulmaz
    assert profile["class_thresholds"] is None
    assert all(pt["state"] is None for pt in profile["scale_points"])

    assert layout["matrix_size"] == 4 * layout["qr_version"] + 17

    # payload, profil ve layout'a doğru referans veriyor mu?
    assert payload["sensor_profile_id"] == profile["profile_id"]
    assert payload["layout_version"] == layout["layout_version"]
