"""Kalibrasyon yöntem aileleri (rapor §6.1 A–E) — tek yönteme kilitlenmez.

Öğrenci 2 görevi (§9.2): bu adayları aynı test setinde karşılaştırıp ortak
metriklerle (cihazlar arası ΔE, tekrarlanabilirlik, ışık dayanıklılığı, süre)
en kararlı olanı seçmek. Benchmark koşumu tests/synthetic altında olacak.

Her yöntem: apply(image, references) -> düzeltilmiş görüntü.  (Şimdilik stub.)
"""

from __future__ import annotations

from typing import Any, Callable

import numpy as np

Image = Any  # numpy.ndarray gelince daraltılacak


def _not_implemented(name: str) -> Callable[..., Image]:
    def _apply(image: Image, references: dict | None = None) -> Image:  # pragma: no cover
        raise NotImplementedError(f"Kalibrasyon yöntemi '{name}' henüz uygulanmadı (rapor §6.1).")

    return _apply


def white_black(image: Image, references: dict) -> Image:
    """Beyaz + siyah iki noktalı referans kalibrasyonu (rapor §6.1 A).

    `references`: {"white": (r,g,b), "black": (r,g,b)} — canonical (homografi
    sonrası) görüntüde `reference_regions`'tan örneklenmiş ortalama renkler.

    Her kanalı BAĞIMSIZ olarak doğrusal esnetir: referans siyah -> 0,
    referans beyaz -> 255. Bu hem genel pozlamayı (kazanç) hem de kanallar
    arası renk sıcaklığı kaymasını (ör. sarımsı ışıkta R kanalının şişmesi)
    tek işlemde düzeltir — klasik "white balance + black point" tekniği.
    """
    white = np.asarray(references["white"], dtype=np.float64)
    black = np.asarray(references["black"], dtype=np.float64)
    span = white - black
    span = np.where(span == 0, 1.0, span)  # sıfıra bölme koruması (dejenere referans)

    corrected = (image.astype(np.float64) - black) / span * 255.0
    return np.clip(corrected, 0, 255).astype(np.uint8)


# Kod -> uygulama. Kodlar sensor_profile.calibration_method.code ile eşleşir.
METHODS: dict[str, Callable[..., Image]] = {
    "white_black": white_black,                                            # A
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
