"""multicolor_patch() kalibrasyon yöntemi testleri (rapor §6.1 C)."""

import numpy as np
import pytest

from packages.color_engine.calibration import (
    MULTICOLOR_PATCH_FIT_RESIDUAL_THRESHOLD,
    get,
    multicolor_patch,
    multicolor_patch_fit_residual,
)


def _apply_cross_channel_distortion(rgb):
    """Kanallar ARASI karışım içeren bir kamera bozulma modeli (ör. kırmızının
    yeşile, yeşilin maviye hafifçe sızması) — white_black/white_gray_black'in
    (her kanalı bağımsız düzelttiği için) telafi edemeyeceği bir durum."""
    mix = np.array(
        [
            [0.9, 0.1, 0.0],
            [0.0, 0.85, 0.05],
            [0.0, 0.0, 0.95],
        ]
    )
    offset = np.array([10.0, 5.0, 8.0])
    return np.clip(np.asarray(rgb, dtype=np.float64) @ mix.T + offset, 0, 255)


def test_multicolor_patch_recovers_cross_channel_distortion():
    true_patches = [(255, 255, 255), (0, 0, 0), (255, 0, 0), (0, 255, 0), (0, 0, 255), (128, 128, 128)]
    captured_patches = [tuple(_apply_cross_channel_distortion(p)) for p in true_patches]

    true_test_color = (100, 180, 90)
    test_captured = np.clip(_apply_cross_channel_distortion(true_test_color), 0, 255).astype(np.uint8)
    image = np.array([[test_captured]], dtype=np.uint8)

    corrected = multicolor_patch(image, {"captured": captured_patches, "true": true_patches})

    # atol=3.5: beyaz yamanın kırpılması (265->255) afin ilişkiyi hafifçe
    # bozuyor + 8-bit yuvarlama ekleniyor; yine de küçük ve kabul edilebilir
    # bir kalıntı hata (A/B'nin telafi edemeyeceği kanal-karışımı sorununu
    # buna rağmen büyük ölçüde düzeltiyor).
    assert np.allclose(corrected[0, 0].astype(np.float64), true_test_color, atol=3.5)


def test_multicolor_patch_requires_at_least_four_points():
    with pytest.raises(ValueError):
        multicolor_patch(
            np.zeros((1, 1, 3), dtype=np.uint8),
            {"captured": [(0, 0, 0), (1, 1, 1)], "true": [(0, 0, 0), (1, 1, 1)]},
        )


def test_get_returns_multicolor_patch_implementation():
    assert get("multicolor_patch") is multicolor_patch


def test_fit_residual_is_low_for_well_conditioned_references():
    """İYİ bir referans seti (gerçek bir afin/kanal-karışımı ilişkisinden
    üretilmiş, test_multicolor_patch_recovers_cross_channel_distortion'daki
    AYNI veri) fit'i KENDİ noktalarında da iyi açıklamalı — residual küçük."""
    true_patches = [(255, 255, 255), (0, 0, 0), (255, 0, 0), (0, 255, 0), (0, 0, 255), (128, 128, 128)]
    captured_patches = [tuple(_apply_cross_channel_distortion(p)) for p in true_patches]

    residual = multicolor_patch_fit_residual({"captured": captured_patches, "true": true_patches})

    assert residual < MULTICOLOR_PATCH_FIT_RESIDUAL_THRESHOLD


def test_fit_residual_is_high_for_inconsistent_references():
    """GERÇEKÇİ bir bozulma senaryosu (28 Eylül, docs/decisions/0004'teki
    C'nin 'yanlış ama emin' bulgusuna motive): referans yamalarından BİRİ
    (ör. baskı kusuru/parlama yüzünden) diğerleriyle TUTARSIZ ölçülmüş --
    hiçbir tek afin dönüşüm hepsini birden açıklayamaz, residual yüksek
    kalmalı (fit'in KENDİ verisinde bile kötü performans göstermesi, bu
    fit'in gerçek görüntüye uygulanmasının GÜVENİLMEZ olduğunun sinyali)."""
    true_patches = [(255, 255, 255), (0, 0, 0), (255, 0, 0), (0, 255, 0), (0, 0, 255), (128, 128, 128)]
    captured_patches = [tuple(_apply_cross_channel_distortion(p)) for p in true_patches]
    # Yeşil yamayı (index 3) tutarsız ölçülmüş gibi boz -- diğer 5 nokta
    # normal afin ilişkiyi izliyor, bu biri UYMUYOR.
    captured_patches[3] = (250, 10, 240)

    residual = multicolor_patch_fit_residual({"captured": captured_patches, "true": true_patches})

    assert residual > MULTICOLOR_PATCH_FIT_RESIDUAL_THRESHOLD
