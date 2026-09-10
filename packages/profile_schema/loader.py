"""JSON profil / layout / payload dosyalarını yükler ve şemaya göre doğrular."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

SCHEMA_DIR = Path(__file__).parent / "schema"
EXAMPLES_DIR = Path(__file__).parent / "examples"

_SCHEMAS = {
    "sensor_profile": SCHEMA_DIR / "sensor_profile.schema.json",
    "layout_version": SCHEMA_DIR / "layout_version.schema.json",
    "label_payload": SCHEMA_DIR / "label_payload.schema.json",
}


def _read_json(path: str | Path) -> dict[str, Any]:
    with open(path, "r", encoding="utf-8") as fh:
        return json.load(fh)


def load_schema(name: str) -> dict[str, Any]:
    if name not in _SCHEMAS:
        raise KeyError(f"Bilinmeyen şema: {name!r}. Seçenekler: {sorted(_SCHEMAS)}")
    return _read_json(_SCHEMAS[name])


def validate(instance: dict[str, Any], schema_name: str) -> dict[str, Any]:
    """`instance`'ı adı verilen şemaya göre doğrular; geçerliyse aynen döndürür.

    jsonschema kurulu değilse doğrulama atlanır (uyarı ile) — CI'da kuruludur.
    """
    schema = load_schema(schema_name)
    try:
        import jsonschema
    except ImportError:  # pragma: no cover
        import warnings

        warnings.warn("jsonschema kurulu değil; doğrulama atlandı", stacklevel=2)
        return instance
    jsonschema.validate(instance=instance, schema=schema)
    return instance


def load_sensor_profile(path: str | Path) -> dict[str, Any]:
    return validate(_read_json(path), "sensor_profile")


def load_layout_version(path: str | Path) -> dict[str, Any]:
    return validate(_read_json(path), "layout_version")


def load_label_payload(path: str | Path) -> dict[str, Any]:
    return validate(_read_json(path), "label_payload")
