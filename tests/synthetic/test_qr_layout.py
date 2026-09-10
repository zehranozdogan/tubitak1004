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
    assert 1 <= len(modules) <= 12
    assert set(modules).issubset(set(candidates))
    for i, a in enumerate(modules):
        for b in modules[i + 1:]:
            assert max(abs(a[0] - b[0]), abs(a[1] - b[1])) >= 3


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
