"""Rapor §11 Aşama A çekirdeği: QR üretimi + fonksiyon maskesi + dağıtılmış modül."""

from packages.profile_schema import validate
from packages.qr_layout import (
    build_layout,
    function_mask,
    generate_qr,
    matrix_size,
    module_matrix,
    reactive_candidates,
    select_reactive_modules,
)
from packages.qr_layout.colors import FINDER_BLACK_MODULE, FINDER_WHITE_MODULE
from packages.qr_layout.reactive import DENSITY_FRACTION


def test_matrix_size():
    assert matrix_size(1) == 21
    assert matrix_size(4) == 33
    assert matrix_size(40) == 177


def test_generate_and_matrix_shape():
    qr = generate_qr("hello", error="h")
    m = module_matrix(qr)
    n = matrix_size(qr.version)
    assert len(m) == n
    assert all(len(row) == n for row in m)


def test_function_mask_covers_finders_and_timing():
    n = matrix_size(4)
    mask = function_mask(4)
    assert mask[0][0] and mask[3][3]            # sol-üst finder
    assert mask[0][n - 1] and mask[n - 1][0]    # sağ-üst / sol-alt finder
    assert mask[6][10] and mask[10][6]          # timing pattern
    assert mask[4 * 4 + 9][8]                   # dark module


def test_reactive_candidates_exclude_function_modules():
    qr = generate_qr("payload-123", error="h")
    mask = function_mask(qr.version)
    candidates = reactive_candidates(qr)
    assert candidates, "aday havuz boş olmamalı"
    assert all(mask[r][c] is False for r, c in candidates)


def test_select_reactive_modules_are_distributed_and_in_pool():
    qr = generate_qr("payload-123", error="h")
    candidates = reactive_candidates(qr)
    modules = select_reactive_modules(candidates, density="low", min_spacing=3, seed=1)
    # Hedef SABİT sayı değil, aday havuzunun oranı (DENSITY_FRACTION) — QR
    # boyutu payload'a göre değiştiği için üst sınırı da orana göre hesapla.
    max_expected = max(5, round(len(candidates) * DENSITY_FRACTION["low"]))
    assert 1 <= len(modules) <= max_expected
    assert set(modules).issubset(set(candidates))
    for i, a in enumerate(modules):
        for b in modules[i + 1:]:
            assert max(abs(a[0] - b[0]), abs(a[1] - b[1])) >= 3


def test_higher_density_yields_more_reactive_cells():
    """Yoğunluk oranla ölçekleniyor: high, low'dan gözle görülür şekilde
    daha çok hücre seçmeli (kullanıcı geri bildirimi: renkli kısımlar azdı)."""
    qr = generate_qr(
        '{"product_id":"TR1","product_type":"LEVREK","production_date":"2026-01-01",'
        '"sensor_profile_id":"GENIPIN_PUTRESIN_v2","layout_version":"QR_SENSOR_v4"}',
        error="h",
    )
    candidates = reactive_candidates(qr)
    low = select_reactive_modules(candidates, density="low", seed=1)
    medium = select_reactive_modules(candidates, density="medium", seed=1)
    high = select_reactive_modules(candidates, density="high", seed=1)
    assert len(low) < len(medium) < len(high)


def test_build_layout_matches_schema():
    qr = generate_qr("payload-123", error="h")
    modules = select_reactive_modules(reactive_candidates(qr), density="low", seed=1)
    layout = build_layout(
        qr,
        modules,
        layout_version="QR_TEST_v1",
        density="low",
        reference_regions={"white": [(9, 9)], "black": [(20, 20)]},
    )
    validate(layout, "layout_version")  # jsonschema yoksa uyarı ile geçer
    assert layout["matrix_size"] == matrix_size(qr.version)
    assert layout["ecc_level"] == "H"


def test_build_layout_explicit_reference_regions_not_overridden():
    """reference_regions elle verilirse (ör. gri/çoklu-yama denemesi) aynen
    korunmalı — varsayılan finder-pattern doldurma yalnızca hiç verilmediğinde
    (None) devreye girmeli."""
    qr = generate_qr("payload-123", error="h")
    layout = build_layout(
        qr, [], layout_version="QR_TEST_v1",
        reference_regions={"white": [(9, 9)], "black": [(20, 20)]},
    )
    assert layout["reference_regions"] == {"white": [[9, 9]], "black": [[20, 20]]}


def test_build_layout_defaults_reference_regions_to_finder_pattern():
    """reference_regions hiç verilmezse (rapor §6.1 D / §10.1: okuyucu
    koordinatları hard-code etmez, bu dosyadan okur) QR'ın finder
    pattern'indeki garanti siyah/beyaz modüllere otomatik düşmeli — böylece
    üretici hiçbir şey yapmasa bile pipeline her zaman geçerli bir kalibrasyon
    referansı bulur (packages.color_engine.pipeline.analyze)."""
    qr = generate_qr("payload-123", error="h")
    layout = build_layout(qr, [], layout_version="QR_TEST_v1")
    assert layout["reference_regions"] == {
        "black": [[FINDER_BLACK_MODULE[0], FINDER_BLACK_MODULE[1]]],
        "white": [[FINDER_WHITE_MODULE[0], FINDER_WHITE_MODULE[1]]],
    }
