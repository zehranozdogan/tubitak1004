"""Kamera koşullarını taklit eden sentetik bozulmalar (rapor §11.2).

Fiziksel telefon/ışık testinden (§11 Aşama B) önce, sanal/sentetik
bozulmalarla (perspektif açı, bulanıklık, parlaklık) decode başarısını
ölçmek için (§11 Aşama A). Girdi/çıktı her zaman PIL.Image.
"""

from __future__ import annotations

import math


def blur(image, radius: float = 2.0):
    """Kamera odak dışı / hareket bulanıklığını taklit eder. radius<=0 -> değişiklik yok."""
    from PIL import ImageFilter

    if radius <= 0:
        return image
    return image.filter(ImageFilter.GaussianBlur(radius=radius))


def brightness(image, factor: float = 1.0):
    """<1 karanlık ortamı, >1 parlama/aşırı pozlamayı taklit eder. 1.0 = değişiklik yok."""
    from PIL import ImageEnhance

    return ImageEnhance.Brightness(image).enhance(factor)


def viewing_angle(image, angle_deg: float, *, fill: tuple[int, int, int] = (255, 255, 255)):
    """Etikete `angle_deg` kadar açıyla bakılmış gibi trapez perspektif uygular
    (rapor §11.2: "Örnek açılar: 0°, 15°, 30°, 45°; homografi ve kalite reddi test edilir").

    Basit yaklaşım: üst kenar açıya göre daralır (cos(açı) oranında). Gerçek
    optik simülasyon değildir ama decoder'ı gerçekçi biçimde zorlar.
    """
    import cv2
    import numpy as np
    from PIL import Image

    if not 0 <= angle_deg < 90:
        raise ValueError("angle_deg 0..90 arasında olmalı (90 dahil değil)")
    if angle_deg == 0:
        return image

    array = np.array(image.convert("RGB"))
    h, w = array.shape[:2]
    compression = math.cos(math.radians(angle_deg))
    offset = (1 - compression) * w / 2

    src = np.float32([[0, 0], [w, 0], [w, h], [0, h]])
    dst = np.float32([[offset, 0], [w - offset, 0], [w, h], [0, h]])
    matrix = cv2.getPerspectiveTransform(src, dst)
    warped = cv2.warpPerspective(array, matrix, (w, h), borderValue=fill)
    return Image.fromarray(warped)
