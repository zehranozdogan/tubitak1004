"""profile_schema — üretici ve tüketicinin ortak sözleşmesi (§6.3, §10.1).

Renk skalası, sınıf eşikleri, layout koordinatları ve kalibrasyon parametreleri
KODA GÖMÜLMEZ; bu paketteki JSON şemalarına uyan dosyalardan okunur.
"""

from packages.profile_schema.loader import (
    SCHEMA_DIR,
    load_label_payload,
    load_layout_version,
    load_sensor_profile,
    validate,
)

__all__ = [
    "SCHEMA_DIR",
    "load_sensor_profile",
    "load_layout_version",
    "load_label_payload",
    "validate",
]
