"""Kalibrasyon yöntem aileleri (rapor §6.1 A–E) — tek yönteme kilitlenmez.

Öğrenci 2 görevi (§9.2): bu adayları aynı test setinde karşılaştırıp ortak
metriklerle (cihazlar arası ΔE, tekrarlanabilirlik, ışık dayanıklılığı, süre)
en kararlı olanı seçmek. Benchmark koşumu tests/synthetic altında olacak.

Her yöntem: apply(image, references) -> düzeltilmiş görüntü.  (Şimdilik stub.)
"""

from __future__ import annotations

from typing import Any, Callable

Image = Any  # numpy.ndarray gelince daraltılacak


def _not_implemented(name: str) -> Callable[..., Image]:
    def _apply(image: Image, references: dict | None = None) -> Image:  # pragma: no cover
        raise NotImplementedError(f"Kalibrasyon yöntemi '{name}' henüz uygulanmadı (rapor §6.1).")

    return _apply


# Kod -> uygulama. Kodlar sensor_profile.calibration_method.code ile eşleşir.
METHODS: dict[str, Callable[..., Image]] = {
    "white_black": _not_implemented("white_black"),                       # A
    "white_gray_black": _not_implemented("white_gray_black"),             # B
    "multicolor_patch": _not_implemented("multicolor_patch"),            # C
    "qr_fixed_regions": _not_implemented("qr_fixed_regions"),            # D
    "algorithmic_white_balance": _not_implemented("algorithmic_white_balance"),  # E
    "learned": _not_implemented("learned"),
}

# Benchmark'ta raporlanacak karar metrikleri (rapor §6 "Karar metrikleri", §11.3)
DECISION_METRICS = [
    "inter_device_delta_e",
    "repeatability_cv",
    "illumination_robustness",
    "class_separation",
    "runtime_ms",
    "print_cost",
]


def get(code: str) -> Callable[..., Image]:
    if code not in METHODS:
        raise KeyError(f"Bilinmeyen kalibrasyon kodu: {code!r}. Seçenekler: {sorted(METHODS)}")
    return METHODS[code]
