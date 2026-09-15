"""Kalibrasyonun gerçekten işe yaradığını kanıtlayan uçtan uca test.

Rapor §11.3 "kalibrasyon kazancı": ham görüntüye göre ΔE ne kadar düştü?

Senaryo: sıcak/sarımsı ışıkta çekilmiş bir fotoğrafta beyaz ve siyah
referanslar da gerçek değerlerinden kaymış görünür (ör. beyaz saf
(255,255,255) değil sarıya çalan bir ton olarak çekilir). white_black()
kalibrasyonu bu kaymayı düzeltmeli: düzeltilmiş rengin gerçek renge olan
ΔE'si, ham (kalibrasyonsuz) rengin ΔE'sinden belirgin biçimde küçük olmalı.
"""

import numpy as np

from packages.color_engine.calibration import white_black
from packages.color_engine.colorspace import delta_e, rgb_to_lab
from packages.color_engine.types import Rgb


def _apply_camera_distortion(true_rgb, white_cam, black_cam):
    """Kameranın gerçek sahneye uyguladığı varsayılan doğrusal bozulma
    (her kanal ayrı gain+ofset) — gerçek beyaz/siyahın 255/0'a değil,
    white_cam/black_cam'e düştüğü bir ışık koşulunu simüle eder."""
    true = np.asarray(true_rgb, dtype=np.float64)
    white_cam = np.asarray(white_cam, dtype=np.float64)
    black_cam = np.asarray(black_cam, dtype=np.float64)
    captured = black_cam + (true / 255.0) * (white_cam - black_cam)
    return tuple(np.clip(captured, 0, 255).astype(np.uint8).tolist())


def test_white_black_calibration_reduces_delta_e_to_true_color():
    # Gerçek (ideal) sahne: tam beyaz, tam siyah, ve "taze" bir sensör rengi.
    true_sensor = (100, 180, 90)

    # Sıcak/sarımsı ışıkta kameranın yakaladığı (bozulmuş) referanslar.
    cam_white = (230, 220, 170)
    cam_black = (45, 35, 15)
    captured_sensor = _apply_camera_distortion(true_sensor, cam_white, cam_black)

    true_lab = rgb_to_lab(Rgb(*true_sensor))

    # Kalibrasyonsuz (ham) okuma: kamera rengi doğrudan gerçek renkle
    # karşılaştırılırsa ne kadar hata var?
    raw_lab = rgb_to_lab(Rgb(*captured_sensor))
    raw_error = delta_e(raw_lab, true_lab)

    # white_black ile düzeltilmiş okuma.
    image = np.array([[captured_sensor]], dtype=np.uint8)  # 1x1 piksel
    corrected = white_black(image, {"white": cam_white, "black": cam_black})
    corrected_rgb = tuple(int(v) for v in corrected[0, 0])
    corrected_lab = rgb_to_lab(Rgb(*corrected_rgb))
    corrected_error = delta_e(corrected_lab, true_lab)

    # Ham okumada gerçek bir renk kayması var (göz ile fark edilir, ΔE > 2).
    assert raw_error > 2.0
    # Kalibrasyon kazancı: düzeltilmiş renk, gerçek renkten "zor fark
    # edilir" eşiğin (ΔE ~ 1) altına düşmeli — ham hatadan çok daha iyi.
    assert corrected_error < raw_error
    assert corrected_error < 1.0
