"""decode_qr_image_with_corners() testleri (rapor §6.2 adım 1)."""

import io

import numpy as np
import pytest
from PIL import Image

from packages.qr_layout.decode import _decode_with_pyzbar, decode_qr_image_with_corners
from packages.qr_layout.generator import generate_qr
from packages.qr_layout.render import png_bytes

pytest.importorskip("pyzbar", reason="pyzbar (zbar) kurulu değil")


def _render(payload: str, *, scale: int = 10, border: int = 4) -> Image.Image:
    import io

    qr = generate_qr(payload, error="h")
    return Image.open(io.BytesIO(png_bytes(qr, scale=scale, border=border))).convert("RGB")


def test_returns_text_and_four_corners():
    image = _render("TEST-CORNERS-1")

    text, corners = decode_qr_image_with_corners(image)

    assert text == "TEST-CORNERS-1"
    assert corners is not None
    assert corners.shape == (4, 2)


def test_corners_are_clockwise_from_top_left():
    scale, border = 10, 4
    image = _render("TEST-CORNERS-2", scale=scale, border=border)

    _text, corners = decode_qr_image_with_corners(image)

    top_left, top_right, bottom_right, bottom_left = corners
    # sol-üst en küçük x+y'ye, sağ-alt en büyüğüne sahip olmalı; yatay
    # komşular aynı y'ye (yaklaşık), dikey komşular aynı x'e yakın olmalı.
    assert top_left[0] < top_right[0]
    assert bottom_left[0] < bottom_right[0]
    assert top_left[1] < bottom_left[1]
    assert top_right[1] < bottom_right[1]


def test_returns_none_corners_when_no_qr_found():
    blank = np.full((100, 100, 3), 255, dtype=np.uint8)

    text, corners = decode_qr_image_with_corners(blank)

    assert text is None
    assert corners is None


def test_pyzbar_fallback_decodes_and_returns_corners_in_cv2_order():
    """Üçüncü dedektör (pyzbar/zbar, 21 Eylül eklendi — bkz. decode.py modül
    notu): gerçek bir fotoğrafta iki cv2 dedektörü de köşeleri bulup metni
    çözemediği bir durumda bunu kurtardı. zbar'ın kendi köşe sırası cv2'den
    FARKLI ([sol-üst, sol-alt, sağ-alt, sağ-üst]) — `_decode_with_pyzbar`
    bunu cv2'nin [sol-üst, sağ-üst, sağ-alt, sol-alt] sırasına çevirmeli,
    aksi halde homografi (color_engine.pipeline adım 2) bozuk/aynalı bir
    canonical görüntü üretir."""
    qr = generate_qr("TEST-PYZBAR-1", error="h")
    image = Image.open(io.BytesIO(png_bytes(qr, scale=10, border=4))).convert("RGB")
    array = np.array(image)[:, :, ::-1]

    text, corners = _decode_with_pyzbar(array)

    assert text == "TEST-PYZBAR-1"
    assert corners is not None
    top_left, top_right, bottom_right, bottom_left = corners
    assert top_left[0] < top_right[0]
    assert bottom_left[0] < bottom_right[0]
    assert top_left[1] < bottom_left[1]
    assert top_right[1] < bottom_right[1]


def test_pyzbar_fallback_reached_only_when_both_cv2_detectors_fail():
    """`decode_qr_image_with_corners` uçtan uca: temiz bir sentetik QR'da
    cv2 dedektörleri zaten başarılı olduğu için pyzbar'a hiç gerek kalmadan
    doğru sonucu vermeli (fallback zincirinin ilk iki halkası hâlâ çalışıyor,
    üçüncü halka eklenmek onları BOZMADI)."""
    image = _render("TEST-PYZBAR-2")

    text, corners = decode_qr_image_with_corners(image)

    assert text == "TEST-PYZBAR-2"
    assert corners is not None
