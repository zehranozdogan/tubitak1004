"""algorithmic_white_balance() kalibrasyon yöntemi testleri (rapor §6.1 E)."""

import numpy as np

from packages.color_engine.calibration import algorithmic_white_balance, get


def test_algorithmic_white_balance_neutralizes_channel_means():
    rng = np.random.default_rng(0)
    base = rng.integers(50, 200, size=(20, 20), endpoint=True).astype(np.float64)
    # Kanallara farklı kazanç uygulayarak yapay bir renk kayması oluştur
    # (ör. sıcak ışıkta kırmızının şişmesi, mavinin sönmesi).
    tinted = np.stack([base * 1.3, base * 1.0, base * 0.7], axis=-1)
    tinted = np.clip(tinted, 0, 255).astype(np.uint8)

    before_ptp = np.ptp(tinted.astype(np.float64).mean(axis=(0, 1)))

    corrected = algorithmic_white_balance(tinted)
    after_ptp = np.ptp(corrected.astype(np.float64).mean(axis=(0, 1)))

    assert after_ptp < before_ptp
    assert after_ptp < 1.0  # kanal ortalamaları düzeltme sonrası pratikte eşit


def test_algorithmic_white_balance_needs_no_references():
    """Diğer yöntemlerden farkı: references parametresi olmadan (None) da
    çalışmalı — hiçbir baskılı referans yamasına ihtiyaç duymaz."""
    image = np.full((5, 5, 3), 128, dtype=np.uint8)

    corrected = algorithmic_white_balance(image, None)

    assert corrected.shape == image.shape


def test_algorithmic_white_balance_handles_zero_channel():
    """Bir kanal tamamen sıfırsa (ör. sentetik test görüntüsü) sıfıra
    bölme olmadan sonuç üretmeli."""
    image = np.zeros((3, 3, 3), dtype=np.uint8)
    image[..., 1] = 100  # yalnızca yeşil kanal dolu

    corrected = algorithmic_white_balance(image)

    assert np.isfinite(corrected).all()


def test_get_returns_algorithmic_white_balance_implementation():
    assert get("algorithmic_white_balance") is algorithmic_white_balance
