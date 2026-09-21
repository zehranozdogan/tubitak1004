"""Rapor §11'in "gerçek kamera koşulu" ruhuna daha yakın, daha zorlu sentetik
testler — şimdiye kadarki testler hep DÜZGÜN/TEK-YÖNLÜ bir bozulma
(doğrusal ışık kayması, sabit açı) varsayıyordu. Burada üç ek senaryo:

1. Düzensiz ışık (bir köşe karanlık, bir köşe parlak — flaş/gölge karışımı)
2. JPEG sıkıştırma artefaktları (telefon fotoğrafları PNG değil)
3. Hareket bulanıklığı (kademeli, quality_score'un doğru tepki verip
   vermediğini görmek için)

Amaç: fiziksel cihaz testine geçmeden önce ucuza bug bulmak.
"""

from __future__ import annotations

import io

import cv2
import numpy as np
from PIL import Image

from packages.color_engine.colorspace import rgb_to_lab
from packages.color_engine.pipeline import analyze
from packages.color_engine.types import Rgb
from packages.qr_layout.colors import STATE_COLORS
from packages.qr_layout.generator import generate_qr, reactive_candidates
from packages.qr_layout.render import render_colored_image

_SCALE, _BORDER = 10, 4


def _build_profile(state: str, other: str) -> dict:
    dark_lab = rgb_to_lab(Rgb(*STATE_COLORS[state]["dark"]))
    other_lab = rgb_to_lab(Rgb(*STATE_COLORS[other]["dark"]))
    return {
        "scale_points": [
            {"value": 0.0, "lab": [dark_lab.L, dark_lab.a, dark_lab.b], "state": state},
            {"value": 1.0, "lab": [other_lab.L, other_lab.a, other_lab.b], "state": other},
        ],
        "class_thresholds": {"note": "test"},
        "calibration_method": {"code": "white_black"},
        "quality_gate": {"min_quality_score": 0.5},
    }


def _render_angled_photo(payload: str, state: str) -> tuple[np.ndarray, dict]:
    """Ortak taban: render edilmiş bir QR'ı hafif açılı bir fotoğrafa çevirir
    (BGR) — bozulma senaryoları bunun üzerine eklenir."""
    qr = generate_qr(payload, error="h")
    n = qr.version * 4 + 17
    sensor_modules = reactive_candidates(qr)[:8]
    layout = {"matrix_size": n, "sensor_modules": [list(m) for m in sensor_modules]}

    image = render_colored_image(qr, layout, state=state, scale=_SCALE, border=_BORDER)
    rgb = np.array(image.convert("RGB"))[:, :, ::-1]
    size = rgb.shape[0]

    src = np.array([[0, 0], [size, 0], [size, size], [0, size]], dtype=np.float32)
    dst = np.array(
        [
            [size * 0.1, size * 0.05],
            [size * 0.9, size * 0.05],
            [size * 0.97, size * 0.95],
            [size * 0.03, size * 0.95],
        ],
        dtype=np.float32,
    )
    transform = cv2.getPerspectiveTransform(src, dst)
    photo = cv2.warpPerspective(rgb, transform, (size, size), borderValue=(180, 180, 180))
    return photo, layout


def _apply_lighting_gradient(image: np.ndarray, *, low: float, high: float) -> np.ndarray:
    """Çapraz bir kazanç gradyanı (bir köşe karanlık, karşı köşe parlak) —
    gerçek bir flaşın/gölgenin tek bir düzgün doğrusal kaymadan farkı:
    KARENİN FARKLI BÖLGELERİ FARKLI ışık alıyor."""
    size = image.shape[0]
    yy, xx = np.mgrid[0:size, 0:size]
    gain = low + (high - low) * (xx + yy) / (2 * size)
    return np.clip(image.astype(np.float64) * gain[..., None], 0, 255).astype(np.uint8)


def _motion_blur_kernel(size: int, angle_deg: float) -> np.ndarray:
    kernel = np.zeros((size, size))
    kernel[size // 2, :] = 1.0
    rotation = cv2.getRotationMatrix2D((size / 2, size / 2), angle_deg, 1)
    kernel = cv2.warpAffine(kernel, rotation, (size, size))
    return kernel / kernel.sum()


# --- 1. Düzensiz ışık ----------------------------------------------------


def test_classification_survives_severe_uneven_lighting():
    """Sınıflandırma (fresh/spoiled gibi UZAK iki durum arasında), aşırı
    düzensiz ışıkta bile (köşeden köşeye ~7 kat kazanç farkı) doğru kalmalı
    — ama confidence bunu 'kolay' bir okuma gibi göstermemeli, düşmeli."""
    photo, layout = _render_angled_photo("TEST-UNEVEN-1", "fresh")
    profile = _build_profile("fresh", "spoiled")

    baseline = analyze(photo, profile, layout)
    severe = analyze(_apply_lighting_gradient(photo, low=0.3, high=2.2), profile, layout)

    assert severe.freshness_class == "fresh"
    assert severe.confidence is not None and baseline.confidence is not None
    assert severe.confidence < baseline.confidence


def test_quality_score_does_not_detect_uneven_lighting():
    """BİLİNEN SINIRLAMA: quality_score global ortalama parlaklık/parlama
    bakar, yerel (bölgesel) aşırılıkları kaçırır — aşırı düzensiz ışıkta
    bile 1.0 verebiliyor. Bu bir regresyon testi değil, mevcut davranışın
    KAYDI: ileride yerel/blok bazlı bir kalite bileşeni eklenirse bu test
    güncellenmeli. Gerçek risk: sistem düzensiz ışıkta "yeniden tara"
    ÖNERMEYEBİLİR; bu yüzden bu senaryoda sınıflandırmanın kendisinin
    sağlam kalması (yukarıdaki test) ekstra önemli."""
    photo, layout = _render_angled_photo("TEST-UNEVEN-2", "fresh")
    profile = _build_profile("fresh", "spoiled")

    result = analyze(_apply_lighting_gradient(photo, low=0.3, high=2.2), profile, layout)

    assert result.quality_score == 1.0


# --- 2. JPEG sıkıştırma ----------------------------------------------------


def test_classification_survives_jpeg_compression():
    """Telefon fotoğrafları PNG değil — gerçekçi (hatta kötü) JPEG kalitesinde
    bile sınıflandırma ve ΔE makul kalmalı."""
    photo, layout = _render_angled_photo("TEST-JPEG-1", "fresh")
    profile = _build_profile("fresh", "spoiled")

    pil_image = Image.fromarray(photo[:, :, ::-1])  # BGR -> RGB (PIL için)
    buf = io.BytesIO()
    pil_image.save(buf, format="JPEG", quality=20)  # kötü, gerçekçi-dışı düşük kalite
    buf.seek(0)
    reloaded = np.array(Image.open(buf).convert("RGB"))[:, :, ::-1]  # RGB -> BGR

    result = analyze(reloaded, profile, layout)

    assert result.rescan_recommended is False
    assert result.freshness_class == "fresh"
    assert result.delta_e is not None and result.delta_e < 10.0


# --- 3. Hareket bulanıklığı ------------------------------------------------


def test_quality_score_decreases_monotonically_with_motion_blur():
    """Bulanıklık arttıkça quality_score düzgünce düşmeli (rastgele
    sıçramamalı) — sharpness bileşeninin (Laplacian varyansı) beklenen
    davranışı."""
    photo, layout = _render_angled_photo("TEST-BLUR-1", "fresh")

    scores = []
    for kernel_size in (3, 7, 11, 15):
        blurred = cv2.filter2D(photo, -1, _motion_blur_kernel(kernel_size, angle_deg=30))
        from packages.color_engine.quality import quality_score

        scores.append(quality_score(blurred))

    assert scores == sorted(scores, reverse=True)  # monoton azalan


def test_severe_motion_blur_triggers_rescan_not_wrong_answer():
    """Yeterince şiddetli bulanıklıkta sistem YANLIŞ ama kendinden emin bir
    sınıf üretmek yerine dürüstçe 'yeniden tara' demeli (§7.1)."""
    photo, layout = _render_angled_photo("TEST-BLUR-2", "fresh")
    profile = _build_profile("fresh", "spoiled")

    blurred = cv2.filter2D(photo, -1, _motion_blur_kernel(31, angle_deg=30))
    result = analyze(blurred, profile, layout)

    assert result.rescan_recommended is True
    assert result.freshness_class is None
