"""Örnek sensor_profile / layout_version dosyalarını okur.

Yollar `packages/profile_schema` paketine göre türetilir — mutlak yol / hardcode YOK.
"""

from packages.profile_schema.loader import (
    EXAMPLES_DIR,
    load_layout_version,
    load_sensor_profile,
)


def example_files():
    return sorted(EXAMPLES_DIR.glob("*.json"))


def load_sensor_profiles():
    out = []
    for path in sorted(EXAMPLES_DIR.glob("*.sensor_profile.json")):
        try:
            out.append(load_sensor_profile(path))
        except Exception:  # noqa: BLE001 - bozuk örnek dosya prototipi engellemesin
            pass
    return out


def load_layout_versions():
    out = []
    for path in sorted(EXAMPLES_DIR.glob("*.layout_version.json")):
        try:
            out.append(load_layout_version(path))
        except Exception:  # noqa: BLE001
            pass
    return out
