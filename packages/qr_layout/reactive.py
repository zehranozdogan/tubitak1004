"""Dağıtılmış reaktif modül seçimi ve layout_version JSON üretimi.

DİKKAT — bu dosya ORTAK sorumluluktadır (Öğrenci 1 + Öğrenci 2, rapor §9).
`select_reactive_modules` şu an basit bir mekânsal-dağıtım sezgiseli kullanır.
Rapor §5.2'nin tam algoritması HENÜZ UYGULANMADI:
  - her reaktif rengin gri-seviye / binary davranışının incelenmesi
  - orijinal siyah/beyaz sınıfını bozmayan pozisyonların tercihi
  - kaçınılmazsa kontrollü "intentional error" + ECC/boyut deneysel karşılaştırma
  - en iyi layout'un layout_version ile sürümlenmesi
Bunlar tests/synthetic altında ölçülüp buraya bağlanacak.

DOĞRULANDI (tests/synthetic/test_decode_verification.py): üç yoğunluk ×
dört renk durumunun tamamı tek bir decoder (OpenCV) ile başarıyla okunuyor.
Rapor ">= 2 decoder" istiyor — ikinci decoder (ör. pyzbar) henüz eklenmedi.
"""

from __future__ import annotations

import random
import zlib

from packages.qr_layout.function_mask import matrix_size

# Yoğunluk -> hedef reaktif hücre sayısı (rapor §8: düşük / orta / yüksek 3 aday)
DENSITY_TARGET = {"low": 12, "medium": 30, "high": 60}


def seed_from_layout_version(layout_version: str) -> int:
    """`layout_version` metninden DETERMİNİSTİK bir seed türetir.

    Amaç: aynı layout_version her zaman aynı reaktif hücre yerleşimini
    üretsin (fiziksel şablon/kalıp tekrarlanabilir olmalı, §5.2/7), ama
    farklı bir layout_version farklı bir yerleşim versinler — koda gömülü
    tek bir sabit seed (ör. hep 0) kullanırsak tüm sürümler aynı geometriye
    çakışır ve "layout_version" versiyonlamanın anlamı kalmaz.
    `zlib.crc32` kullanılır (Python'un `hash()`'i süreçler arası kararlı
    değildir, PYTHONHASHSEED'e bağlıdır).
    """
    return zlib.crc32(layout_version.encode("utf-8"))


def _chebyshev(a: tuple[int, int], b: tuple[int, int]) -> int:
    return max(abs(a[0] - b[0]), abs(a[1] - b[1]))


def select_reactive_modules(
    candidates: list[tuple[int, int]],
    *,
    density: str = "low",
    min_spacing: int = 3,
    seed: int = 0,
) -> list[tuple[int, int]]:
    """Aday havuzdan küçük ve mekânsal olarak dağıtılmış bir alt küme seçer.

    Basit greedy: karıştır, aralarında en az `min_spacing` Chebyshev mesafesi
    kalacak şekilde hedef sayıya kadar seç. (Geçici — bkz. modül başlığı.)
    """
    if density not in DENSITY_TARGET:
        raise ValueError(f"density 'low'|'medium'|'high' olmalı, verilen: {density!r}")
    target = DENSITY_TARGET[density]
    pool = list(candidates)
    random.Random(seed).shuffle(pool)

    chosen: list[tuple[int, int]] = []
    for cell in pool:
        if len(chosen) >= target:
            break
        if all(_chebyshev(cell, c) >= min_spacing for c in chosen):
            chosen.append(cell)
    return sorted(chosen)


def build_layout(
    qr,
    sensor_modules: list[tuple[int, int]],
    *,
    layout_version: str,
    density: str = "low",
    reference_regions: dict[str, list[tuple[int, int]]] | None = None,
    intentional_errors: list[tuple[int, int]] | None = None,
) -> dict:
    """layout_version.schema.json'a uyan sözlük üretir (koordinatlar dışarıda tutulur)."""
    version = qr.version
    return {
        "layout_version": layout_version,
        "qr_version": version,
        "matrix_size": matrix_size(version),
        "ecc_level": (qr.error or "H").upper(),
        "module_density": density,
        "sensor_modules": [[r, c] for r, c in sensor_modules],
        "reference_regions": {
            k: [[r, c] for r, c in v] for k, v in (reference_regions or {}).items()
        },
        "intentional_errors": [[r, c] for r, c in (intentional_errors or [])],
        "decoder_check": {
            "decoders": [],
            "color_states": ["fresh", "transition", "spoiled"],
            "decode_success_rate": 0.0,
        },
    }
