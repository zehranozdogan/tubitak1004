"""Hafif bozulma altında QR hâlâ okunmalı — sağlıklı referans (rapor §11.2).

Bunlar CI'da her zaman geçmesi gereken, GERÇEKÇİ/HAFİF koşullardır. Ağır
koşulların (güçlü bulanıklık + yüksek açı birlikte gibi) başarısız olması
BEKLENİR ve hata değildir — gerçek uygulamada bu "Yeniden tara" (§7.1) ile
karşılanır. Tam başarı-oranı tablosu için elle çalıştır:

    python3 tests/synthetic/benchmark_distortion.py

BULGU (decode.py geçmişi): OpenCV'nin TEMEL dedektörü (`cv2.QRCodeDetector`)
45° görüntüleme açısında %0 başarılıydı; ArUco tabanlı dedektöre
(`cv2.QRCodeDetectorAruco`, aynı pakette, ek bağımlılık yok) geçilince genel
başarı %69 -> %86'ya çıktı ve 45° %0 -> %67 oldu. Bu, raporun neden ">= 2
decoder" karşılaştırması istediğinin somut kanıtı (§11) — tek bir decoder
seçimi bile sonucu köklü değiştiriyor. 15° artık TÜM kombinasyonlarda
(81/81) güvenilir; bu yüzden "kesin geçmeli" testler 15°'ye çekildi.
"""

from __future__ import annotations

import json

import pytest

from packages.qr_layout import (
    build_layout,
    generate_qr,
    reactive_candidates,
    select_reactive_modules,
)
from packages.qr_layout.decode import decode_qr_image
from packages.qr_layout.distortion import blur, brightness, viewing_angle
from packages.qr_layout.render import render_colored_image

cv2 = pytest.importorskip("cv2", reason="opencv-python-headless kurulu değil")

PAYLOAD = {
    "product_id": "TR-DISTORTION-TEST",
    "product_type": "LEVREK",
    "production_date": "2026-09-15",
    "sensor_profile_id": "GENIPIN_PUTRESIN_v2",
    "layout_version": "QR_SENSOR_v4",
}
PAYLOAD_TEXT = json.dumps(PAYLOAD, ensure_ascii=False, separators=(",", ":"))


def _base_image():
    qr = generate_qr(PAYLOAD_TEXT, error="h")
    modules = select_reactive_modules(reactive_candidates(qr), density="high", seed=1)
    layout = build_layout(qr, modules, layout_version=PAYLOAD["layout_version"], density="high")
    return render_colored_image(qr, layout, state="spoiled", scale=10, border=4)


def _assert_decodes(image) -> None:
    decoded = decode_qr_image(image)
    assert decoded is not None, "QR okunamadı"
    assert json.loads(decoded) == PAYLOAD


def test_mild_angle_decodes():
    _assert_decodes(viewing_angle(_base_image(), 15))


def test_mild_blur_decodes():
    _assert_decodes(blur(_base_image(), radius=1.0))


def test_low_light_decodes():
    _assert_decodes(brightness(_base_image(), factor=0.6))


def test_slight_glare_decodes():
    _assert_decodes(brightness(_base_image(), factor=1.3))


def test_combined_mild_conditions_decode():
    """Gerçekçi bir "elde tutulmuş telefon" senaryosu: hafif açı + hafif
    bulanıklık + hafif düşük ışık, aynı anda."""
    image = _base_image()
    image = viewing_angle(image, 15)
    image = blur(image, radius=0.8)
    image = brightness(image, factor=0.8)
    _assert_decodes(image)
