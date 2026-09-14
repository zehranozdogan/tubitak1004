"""Etiket paketini üretir: label_payload JSON + layout_version JSON + PNG/PDF
+ sentetik taze/geçiş/bozulma görselleri (renkli PNG).

Rapor §8 çıktıları.

DB SEÇİMİ (bkz. docs/decisions/0003-database-placeholder.md): export_label()
şu an yalnızca dosyaya yazar. DB bağlanınca aynı fonksiyon içine (veya ayrı
bir save_batch() adımına) "batches" tablosuna INSERT eklenecek; dönüş
sözlüğüne DB kimliği (ör. "batch_id") eklenebilir, mevcut anahtarlar
("qr", "layout", "paths") kalmalı ki çağıran kod bozulmasın.
"""

from __future__ import annotations

import json
from pathlib import Path

from packages.profile_schema import validate
from packages.qr_layout import (
    build_layout,
    generate_qr,
    reactive_candidates,
    seed_from_layout_version,
    select_reactive_modules,
)
from packages.qr_layout.render import save_pdf, save_png, save_synthetic_states


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


def export_label(payload: dict, out_dir: str | Path, *, density: str = "low", seed: int | None = None) -> dict:
    """seed=None ise `layout_version`'dan türetilir: aynı sürüm -> aynı
    reaktif yerleşim (fiziksel şablon tekrarlanabilir, §5.2/7); farklı bir
    sürüm -> farklı yerleşim. Elle seed vermek yalnızca deney/test içindir.
    """
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    if seed is None:
        seed = seed_from_layout_version(payload["layout_version"])

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

    synthetic = save_synthetic_states(qr, layout, out, stem=stem)
    paths.update({f"state_{state}": p for state, p in synthetic.items()})

    return {"qr": qr, "layout": layout, "paths": paths}
