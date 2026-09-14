"""Örnek sensor_profile / layout_version dosyalarını okur.

Yollar `packages/profile_schema` paketine göre türetilir — mutlak yol / hardcode YOK.

DB SEÇİMİ (bkz. docs/decisions/0003-database-placeholder.md): şu an dosya
tabanlı (EXAMPLES_DIR taraması). DB bağlanınca bu iki fonksiyonun GÖVDESİ
dosya taramasından DB sorgusuna değişecek; İMZASI (parametresiz, dönüş
`list[dict]`) aynı kalırsa admin_view.py hiç değişmeden geçiş yapılabilir.
"""

from packages.profile_schema.loader import (
    EXAMPLES_DIR,
    load_layout_version,
    load_sensor_profile,
)


def example_files():
    return sorted(EXAMPLES_DIR.glob("*.json"))


def load_sensor_profiles() -> list[dict]:
    """DB'ye bağlanınca: "SELECT * FROM sensor_profiles" benzeri bir sorguya döner."""
    out = []
    for path in sorted(EXAMPLES_DIR.glob("*.sensor_profile.json")):
        try:
            out.append(load_sensor_profile(path))
        except Exception:  # noqa: BLE001 - bozuk örnek dosya prototipi engellemesin
            pass
    return out


def load_layout_versions() -> list[dict]:
    """DB'ye bağlanınca: "SELECT * FROM layout_versions" benzeri bir sorguya döner."""
    out = []
    for path in sorted(EXAMPLES_DIR.glob("*.layout_version.json")):
        try:
            out.append(load_layout_version(path))
        except Exception:  # noqa: BLE001
            pass
    return out
