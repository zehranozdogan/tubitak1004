"""RGB <-> CIE Lab dönüşümü ve renk farkı (ΔE) hesaplamaları (rapor §6.2 adım 6).

scikit-image'ın doğrulanmış, standart uygulamaları kullanılır — CIEDE2000
gibi formüller elle yazıldığında ince hatalara açıktır (hue açısı sarması,
koşullu terimler); burada tekerlek yeniden icat edilmiyor.
"""

from __future__ import annotations

import numpy as np
from skimage.color import deltaE_ciede2000, rgb2lab

from packages.color_engine.types import Lab, Rgb


def rgb_to_lab(rgb: Rgb) -> Lab:
    """sRGB (0-255 kanal) -> CIE Lab (D65 aydınlatıcı, skimage varsayılanları)."""
    normalized = np.array([[[rgb.r / 255.0, rgb.g / 255.0, rgb.b / 255.0]]], dtype=np.float64)
    L, a, b = rgb2lab(normalized)[0, 0]
    return Lab(L=float(L), a=float(a), b=float(b))


def delta_e(lab1: Lab, lab2: Lab) -> float:
    """CIEDE2000 renk farkı. 0 = özdeş; ~1 civarı "zor fark edilir" eşiği,
    büyüdükçe fark büyür (rapor §6.1 "Karar metrikleri": inter_device_delta_e vb.)."""
    a = np.array([[lab1.L, lab1.a, lab1.b]], dtype=np.float64)
    b = np.array([[lab2.L, lab2.a, lab2.b]], dtype=np.float64)
    return float(deltaE_ciede2000(a, b)[0])
