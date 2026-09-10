"""Etiket paketini üretir: label_payload JSON + layout_version JSON + PNG + PDF.

Rapor §8 çıktıları. Sentetik taze/geçiş/bozulma görselleri: qr_layout.render TODO.
"""

from __future__ import annotations

import json
from pathlib import Path

from packages.profile_schema import validate
from packages.qr_layout import (
    build_layout,
    generate_qr,
    reactive_candidates,
    select_reactive_modules,
)
from packages.qr_layout.render import save_pdf, save_png


def build_label_payload(
    product_id: str,
    product_type: str,
    production_date: str,
    sensor_profile_id: str,
    layout_version: str,
) -> dict:
    payload = {
        "product_id": product_id.strip(),
        "product_type": product_type.strip().upper(),
        "production_date": production_date.strip(),
        "sensor_profile_id": sensor_profile_id.strip(),
        "layout_version": layout_version.strip(),
    }
    return validate(payload, "label_payload")


def _payload_qr_text(payload: dict) -> str:
    return json.dumps(payload, ensure_ascii=False, separators=(",", ":"))


def export_label(payload: dict, out_dir: str | Path, *, density: str = "low", seed: int = 0) -> dict:
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)

    qr = generate_qr(_payload_qr_text(payload), error="h")
    modules = select_reactive_modules(reactive_candidates(qr), density=density, seed=seed)
    layout = build_layout(qr, modules, layout_version=payload["layout_version"], density=density)
    validate(layout, "layout_version")

    stem = f"{payload['product_id']}_{payload['layout_version']}"
    paths = {
        "payload_json": out / f"{stem}.label_payload.json",
        "layout_json": out / f"{stem}.layout_version.json",
        "png": out / f"{stem}.png",
        "pdf": out / f"{stem}.pdf",
    }
    paths["payload_json"].write_text(
        json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    paths["layout_json"].write_text(
        json.dumps(layout, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    save_png(qr, paths["png"], scale=10)
    save_pdf(qr, paths["pdf"], scale=10)

    return {"qr": qr, "layout": layout, "paths": paths}
