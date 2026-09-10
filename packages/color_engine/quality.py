"""Görüntü kalitesi skoru ve 'Yeniden tara' kararı (rapor §6.2/8, §7.1).

Düşük kalitede uygulama SINIF ÜRETMEZ; taramayı reddedip 'Yeniden tara' der.
"""

from __future__ import annotations

from typing import Any

Image = Any

DEFAULT_MIN_QUALITY = 0.5


def quality_score(image: Image) -> float:  # pragma: no cover - stub
    """0..1 kalite skoru.

    TODO (§7.1): bulanıklık (Laplacian varyansı), parlama/doygunluk oranı,
    ortalama parlaklık, QR köşe tespiti güveni bileşenlerinden birleşik skor.
    """
    raise NotImplementedError("quality_score henüz uygulanmadı (numpy/opencv gerekiyor).")


def should_rescan(score: float, min_quality: float = DEFAULT_MIN_QUALITY) -> bool:
    """Kalite eşiğin altındaysa True (kullanıcıya 'Yeniden tara')."""
    return score < min_quality
