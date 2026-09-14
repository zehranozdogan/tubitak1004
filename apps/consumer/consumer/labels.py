"""out/ altında üretilmiş etiketleri okur (rapor §8 çıktıları).

DB SEÇİMİ (bkz. docs/decisions/0003-database-placeholder.md): şu an dosya
tabanlı. DB bağlanınca bu iki fonksiyon "batches" tablosuna sorguya dönüşür;
imza (list[dict] / int) aynı kalırsa çağıran ekranlar (admin_view, labels_view)
değişmeden geçiş yapar.
"""

from __future__ import annotations

import json
from pathlib import Path

# cwd'den bağımsız: her zaman repo kökündeki out/ (.gitignore'da /out/)
OUT_DIR = Path(__file__).resolve().parents[3] / "out"

_SUFFIX = ".label_payload.json"


def load_labels(out_dir: Path = OUT_DIR) -> list[dict]:
    """Üretilmiş etiketleri en yeniden en eskiye sırayla döndürür."""
    labels: list[dict] = []
    if not out_dir.exists():
        return labels
    for f in sorted(out_dir.glob(f"*{_SUFFIX}"), reverse=True):
        try:
            payload = json.loads(f.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            continue
        payload["_stem"] = f.name[: -len(_SUFFIX)]
        labels.append(payload)
    return labels


def count_labels(out_dir: Path = OUT_DIR) -> int:
    if not out_dir.exists():
        return 0
    return len(list(out_dir.glob(f"*{_SUFFIX}")))


def delete_label(stem: str, out_dir: Path = OUT_DIR) -> int:
    """`stem` ile başlayan tüm dosyaları (json/png/pdf, 3 durum görseli dahil)
    kalıcı olarak siler. Silinen dosya sayısını döndürür.
    """
    if not out_dir.exists():
        return 0
    deleted = 0
    for f in out_dir.glob(f"{stem}.*"):
        try:
            f.unlink()
            deleted += 1
        except OSError:
            pass
    return deleted
