"""Işık düzensizliği için LAYOUT-FARKINDA, SADECE BİLGİLENDİRİCİ sinyal
(rapor §6.2/§7.1, 21 Eylül, kullanıcı geri bildirimiyle aynı gün düzeltildi).

Arka plan (iki aşamalı öğrenme):
1. `test_realistic_distortions.py::test_quality_score_does_not_detect_
   uneven_lighting` bir öncekini (ham piksel kenar-örneklemesi) hem
   sentetik hem GERÇEK cihaz fotoğraflarıyla test edip güvenilmez bulmuştu.
2. Bu dosyanın İLK sürümünde (bkz. git geçmişi) bunun yerine TAHMİN değil,
   üç finder köşesindeki BİLİNEN AYNI rengin (beyaz) ölçümüne dayanan bir
   yaklaşım geldi — ama confidence'a SAYISAL bir çarpan olarak uygulandı.
   Kullanıcı ("bence sıkıntı olmuş... 0.6ysa harbiden gölge düşse 0a
   yaklaşır") bunu sorguladı; 2 gerçek fotoğraf + üzerlerine eklenen KÜÇÜK
   ek gölgelerle test edilince haklı çıktı: bilinen iyi bir fotoğrafta 0.775
   olan çarpan, yarım çerçeveye %50 hafif kararma eklenince 0.237'ye
   düşüyordu. N=2 gerçek veriyle böyle bir çarpan haklı çıkarılamaz.

Şimdiki hâl: `corner_cv` hesaplanır ama confidence'ı SAYISAL olarak
ETKİLEMEZ — yalnızca belirgin olduğunda (`_CORNER_CV_NOTE_THRESHOLD`)
notes'a bilgi eklenir. 2 gerçek cihaz fotoğrafıyla doğrulandı: ikisi de
(cv 0.09 ve 0.15) bu eşiğin (0.25) altında kalıp not TETİKLEMİYOR — yani
bilinen iyi fotoğraflar yanlış alarm ÜRETMİYOR."""

from __future__ import annotations

import cv2
import numpy as np

from packages.color_engine.colorspace import rgb_to_lab
from packages.color_engine.pipeline import analyze
from packages.color_engine.types import Rgb
from packages.qr_layout.colors import (
    FINDER_BLACK_MODULE,
    FINDER_WHITE_MODULE,
    STATE_COLORS,
    finder_pattern_corner_positions,
)
from packages.qr_layout.generator import generate_qr, reactive_candidates
from packages.qr_layout.render import render_colored_image

_SCALE, _BORDER = 10, 4


def test_finder_pattern_corner_positions_mirrors_top_left_correctly():
    """top_right/bottom_left, top_left'in (satır, sütun)'unu `matrix_size-1`
    etrafında aynalamalı — QR'ın üç finder pattern'i simetrik yerleşir
    (yalnızca sağ-alt köşede finder YOKTUR, bu QR'ın kendi tasarımı)."""
    matrix_size = 25
    positions = finder_pattern_corner_positions(matrix_size)

    assert positions["top_left"]["black"] == FINDER_BLACK_MODULE
    assert positions["top_left"]["white"] == FINDER_WHITE_MODULE

    last = matrix_size - 1
    br, bc = FINDER_BLACK_MODULE
    wr, wc = FINDER_WHITE_MODULE
    assert positions["top_right"]["black"] == (br, last - bc)
    assert positions["top_right"]["white"] == (wr, last - wc)
    assert positions["bottom_left"]["black"] == (last - br, bc)
    assert positions["bottom_left"]["white"] == (last - wr, wc)


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
    size = image.shape[0]
    yy, xx = np.mgrid[0:size, 0:size]
    gain = low + (high - low) * (xx + yy) / (2 * size)
    return np.clip(image.astype(np.float64) * gain[..., None], 0, 255).astype(np.uint8)


def _apply_corner_shadow(image: np.ndarray, *, strength: float, radius_frac: float = 0.55) -> np.ndarray:
    """Sol-üst köşede yoğunlaşan tek taraflı bir gölge (gerçek bir el/gövde
    gölgesi gibi) — köşeden köşeye YAYGIN bir gradyandan (`_apply_lighting_
    gradient`) farklı olarak, üç finder köşesinden SADECE BİRİNİ güçlü
    şekilde karartır. `_apply_lighting_gradient`'ın en uçları bile (beyaz
    modülü 255'e satüre ederek) `_CORNER_CV_NOTE_THRESHOLD`'u geçemiyordu
    (elle ölçüldü) — bu daha gerçekçi TEK YÖNLÜ gölge deseni geçiyor."""
    size = image.shape[0]
    yy, xx = np.mgrid[0:size, 0:size]
    dist = np.sqrt((xx / size) ** 2 + (yy / size) ** 2) / np.sqrt(2)
    gain = np.where(dist < radius_frac, strength + (1 - strength) * (dist / radius_frac), 1.0)
    return np.clip(image.astype(np.float64) * gain[..., None], 0, 255).astype(np.uint8)


def test_mild_and_moderate_lighting_gradient_do_not_trigger_note():
    """Gerçekçi düzensiz ışıkta (hafif vinyetleme, hatta sentetik "aşırı"
    köşeden köşeye 7 kat kazanç farkı) sınıflandırma sağlam kalmalı VE not
    tetiklenmemeli — 2 gerçek cihaz fotoğrafında (cv 0.09/0.15) da not
    tetiklenmediği doğrulandı, bu eşiğin gereksiz yere hassas olmadığını
    gösteriyor."""
    photo, layout = _render_angled_photo("TEST-CORNER-1", "fresh")
    profile = _build_profile("fresh", "spoiled")

    mild = analyze(_apply_lighting_gradient(photo, low=0.85, high=1.2), profile, layout)
    severe_gradient = analyze(_apply_lighting_gradient(photo, low=0.3, high=2.2), profile, layout)

    for result in (mild, severe_gradient):
        assert result.freshness_class == "fresh"
        assert result.rescan_recommended is False
        assert result.notes == []


def test_strong_single_corner_shadow_adds_explanatory_note_but_does_not_change_confidence_formula():
    """Belirgin, TEK köşeyi vuran bir gölgede (ör. elin/gövdenin QR'ın bir
    ucuna düşürdüğü gölge) notes'a AÇIKÇA yazılmalı — ama confidence, bu
    sinyalden SAYISAL olarak etkilenmemeli (yalnızca `_module_reading_
    confidence`'a bağlı kalmalı); sınıflandırma/rescan da bundan
    etkilenmemeli, bu SADECE bilgilendirici bir işaret (bkz. modül
    docstring'i — sert bir çarpan denendi, kullanıcı geri bildirimiyle
    aşırı bulundu, geri alındı)."""
    photo, layout = _render_angled_photo("TEST-CORNER-2", "fresh")
    profile = _build_profile("fresh", "spoiled")

    shadowed = _apply_corner_shadow(photo, strength=0.15)
    result = analyze(shadowed, profile, layout)

    assert any("Referans köşeleri" in note for note in result.notes)
    assert result.freshness_class == "fresh"
    assert result.rescan_recommended is False
