"""Görüntü kalitesi skoru ve 'Yeniden tara' kararı (rapor §6.2/8, §7.1).

Düşük kalitede uygulama SINIF ÜRETMEZ; taramayı reddedip 'Yeniden tara' der.
"""

from __future__ import annotations

import cv2
import numpy as np

Image = np.ndarray

DEFAULT_MIN_QUALITY = 0.5

# Laplacian varyansı bu değerin üstündeyse "keskin" (skor 1.0) kabul edilir;
# altındaysa oransal olarak düşer. Değer deneysel — gerçek etiket
# görüntüleriyle kalibre edilecek (rapor §11 Aşama B).
_SHARPNESS_SATURATING_VARIANCE = 300.0


def _to_gray(image: Image) -> Image:
    if image.ndim == 2:
        return image
    return cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)


def _sharpness_score(gray: Image) -> float:
    """0..1: Laplacian varyansı (yüksek = keskin, düşük = bulanık)."""
    variance = cv2.Laplacian(gray, cv2.CV_64F).var()
    return float(min(1.0, variance / _SHARPNESS_SATURATING_VARIANCE))


def _glare_score(gray: Image, *, saturated_threshold: int = 250) -> float:
    """0..1: parlama/doygunluk piksel oranı düşükse 1.0, artınca 0'a yaklaşır.

    %5'e kadar parlama toleranslı; %25 ve üzeri tamamen kötü (skor 0) sayılır.
    """
    saturated_ratio = float(np.mean(gray >= saturated_threshold))
    return float(max(0.0, 1.0 - max(0.0, saturated_ratio - 0.05) / 0.20))


def _brightness_score(gray: Image, *, low: int = 40, high: int = 220) -> float:
    """0..1: ortalama parlaklık [low, high] aralığındaysa 1.0, dışına çıktıkça düşer."""
    mean = float(gray.mean())
    if low <= mean <= high:
        return 1.0
    if mean < low:
        return float(max(0.0, 1.0 - (low - mean) / low))
    return float(max(0.0, 1.0 - (mean - high) / (255 - high)))


def quality_score(image: Image) -> float:
    """0..1 birleşik kalite skoru: keskinlik + parlama + ortalama parlaklık.

    QR köşe tespiti güveni burada DEĞİL — o, `pipeline.analyze()` içinde
    QR köşeleri zaten bulunduktan/bulunamadıktan sonra ayrıca bu skorla
    birleştirilecek (rapor §7.1). Bu fonksiyon yalnızca görüntünün kendi
    (kamera kaynaklı) kalitesine bakar.
    """
    gray = _to_gray(image)
    components = (
        _sharpness_score(gray),
        _glare_score(gray),
        _brightness_score(gray),
    )
    return float(sum(components) / len(components))


def should_rescan(score: float, min_quality: float = DEFAULT_MIN_QUALITY) -> bool:
    """Kalite eşiğin altındaysa True (kullanıcıya 'Yeniden tara')."""
    return score < min_quality
