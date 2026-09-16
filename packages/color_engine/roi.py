"""Reaktif hücre ROI örnekleme (rapor §6.2 adım 4-5).

Canonical (homografi sonrası) görüntüde her reaktif modülün merkez
bölgesinden piksel örnekler; parlama/gölge/kenar piksellerini eleyip
sağlam (median) bir temsilci renk çıkarır.
"""

from __future__ import annotations

import numpy as np

from packages.qr_layout.colors import module_pixel_center

Image = np.ndarray


def sample_module_roi(image: Image, row: int, col: int, *, scale: int, border: int, margin: int = 2) -> Image:
    """Bir modülün merkez bölgesinden piksel yamasını (patch) döndürür.

    `margin`: modül sınırından içeri kaç piksel çekileceği — komşu modüle
    taşan kenar/anti-aliasing piksellerine karşı güvenlik payı.
    Dönen: (k, k, 3) uint8 piksel yaması, k = scale - 2*margin.
    """
    y, x = module_pixel_center(row, col, scale=scale, border=border)
    half = max(scale // 2 - margin, 1)
    return image[y - half : y + half + 1, x - half : x + half + 1]


def robust_module_color(patch: Image, *, glare_threshold: int = 250, shadow_threshold: int = 5) -> np.ndarray:
    """Bir piksel yamasından MEDIAN ile sağlam bir temsilci RGB çıkarır.

    Aşırı parlak (glare/doygunluk) veya aşırı karanlık (gölge) pikselleri
    eler (rapor §6.2 adım 4: "parlama, gölge ve kenar piksellerinin
    elenmesi") — median, birkaç aykırı pikselin ortalamayı (mean) kaydırma
    riskine karşı da ayrıca dayanıklıdır. Tüm piksel yaması aykırıysa
    (elemeden hiçbir şey kalmazsa) yine de bütün yamanın medyanı döner —
    boş dizi hatası vermez.
    """
    flat = patch.reshape(-1, 3).astype(np.float64)
    brightness = flat.mean(axis=1)
    valid = (brightness < glare_threshold) & (brightness > shadow_threshold)
    usable = flat[valid] if valid.any() else flat
    return np.median(usable, axis=0)
