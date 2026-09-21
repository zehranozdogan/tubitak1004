"""Kasıtlı hata modülleri — rapor §5.2/4: "Binary sınıf değişimi kaçınılmazsa
kontrollü hata modülleri". Tam sayısal sınır için (kaç tanesi güvenle tolere
edilir) elle çalıştır:

    python3 tests/synthetic/benchmark_intentional_errors.py

Bu dosyadaki testler CI'da her zaman geçmesi gereken, KÜÇÜK/GÜVENLİ
senaryolardır.
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
from packages.qr_layout.colors import module_color
from packages.qr_layout.generator import module_matrix
from packages.qr_layout.reactive import select_intentional_errors
from packages.qr_layout.render import render_colored_image

cv2 = pytest.importorskip("cv2", reason="opencv-python-headless kurulu değil")
from packages.qr_layout.decode import decode_qr_image  # noqa: E402

PAYLOAD = {
    "product_id": "TR-IERR-TEST",
    "product_type": "LEVREK",
    "production_date": "2026-09-17",
    "sensor_profile_id": "GENIPIN_PUTRESIN_v2",
    "layout_version": "QR_SENSOR_v4",
}
PAYLOAD_TEXT = json.dumps(PAYLOAD, ensure_ascii=False, separators=(",", ":"))


def _qr_and_candidates():
    qr = generate_qr(PAYLOAD_TEXT, error="h")
    return qr, reactive_candidates(qr)


def test_select_intentional_errors_stays_in_pool_and_respects_exclude():
    qr, candidates = _qr_and_candidates()
    sensor_modules = set(select_reactive_modules(candidates, density="low", seed=1))

    errors = select_intentional_errors(candidates, count=10, exclude=sensor_modules, seed=1)

    assert len(errors) == 10
    assert set(errors).issubset(set(candidates))
    assert set(errors).isdisjoint(sensor_modules), "kasıtlı hata reaktif hücreyle çakışmamalı"


def test_select_intentional_errors_rejects_count_larger_than_pool():
    qr, candidates = _qr_and_candidates()
    with pytest.raises(ValueError):
        select_intentional_errors(candidates, count=len(candidates) + 1, seed=1)


def test_render_colored_image_flips_bit_at_intentional_error_positions():
    """Kasıtlı hata hücresi, GERÇEK bitinin tersine karşılık gelen tonla
    render edilmeli (module_color ile karşılaştırarak doğrula)."""
    qr, candidates = _qr_and_candidates()
    matrix = module_matrix(qr)
    error_cell = candidates[0]
    r, c = error_cell
    true_bit = matrix[r][c]

    layout = build_layout(
        qr, [], layout_version=PAYLOAD["layout_version"], intentional_errors=[error_cell]
    )
    image = render_colored_image(qr, layout, state=None, scale=10, border=4)

    scale, border = 10, 4
    x = (c + border) * scale + scale // 2
    y = (r + border) * scale + scale // 2
    px = image.getpixel((x, y))
    expected_flipped = module_color(1 - true_bit, False, None)
    expected_true = module_color(true_bit, False, None)
    assert px == expected_flipped
    assert px != expected_true


def test_small_number_of_intentional_errors_still_decodes():
    """Güvenli aralıkta (bkz. benchmark) az sayıda kasıtlı hata, ECC ile
    tolere edilip QR hâlâ doğru okunmalı — regresyon güvencesi."""
    qr, candidates = _qr_and_candidates()
    sensor_modules = select_reactive_modules(candidates, density="high", seed=1)
    errors = select_intentional_errors(
        candidates, count=15, exclude=set(sensor_modules), seed=1
    )
    layout = build_layout(
        qr, sensor_modules, layout_version=PAYLOAD["layout_version"],
        density="high", intentional_errors=errors,
    )
    assert layout["intentional_errors"] == [[r, c] for r, c in errors]

    image = render_colored_image(qr, layout, state="spoiled", scale=10, border=4)
    decoded = decode_qr_image(image)
    assert decoded is not None
    assert json.loads(decoded) == PAYLOAD


def test_no_intentional_errors_by_default():
    """build_layout() intentional_errors verilmezse boş kalmalı — reference_
    regions'ın aksine bu OTOMATİK doldurulmaz, çünkü kasıtlı hata her zaman
    bilinçli bir tasarım kararı olmalı (rapor §5.2/4: "kaçınılmazsa")."""
    qr, candidates = _qr_and_candidates()
    layout = build_layout(qr, [], layout_version=PAYLOAD["layout_version"])
    assert layout["intentional_errors"] == []
