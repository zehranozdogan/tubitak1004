"""Reaktif hücrelerin renkli render'ı (rapor §5, §8) — modül sınıfı korunuyor mu?"""

from packages.qr_layout import (
    build_layout,
    generate_qr,
    reactive_candidates,
    select_reactive_modules,
)
from packages.qr_layout.colors import STATE_COLORS, module_color
from packages.qr_layout.render import render_colored_image, save_synthetic_states


def _sample_layout():
    qr = generate_qr("payload-colors", error="h")
    modules = select_reactive_modules(reactive_candidates(qr), density="low", seed=1)
    layout = build_layout(qr, modules, layout_version="TEST", density="low")
    return qr, layout


def test_module_color_preserves_dark_light_class():
    for state in ("fresh", "transition", "spoiled", None):
        dark_sensor = module_color(1, True, state)
        light_sensor = module_color(0, True, state)
        dark_plain = module_color(1, False, state)
        light_plain = module_color(0, False, state)

        # koyu ton her zaman açık tondan daha az parlak olmalı (luma karşılaştırması)
        def luma(rgb):
            r, g, b = rgb
            return 0.299 * r + 0.587 * g + 0.114 * b

        assert luma(dark_sensor) < luma(light_sensor)
        assert dark_plain == (0, 0, 0)
        assert light_plain == (255, 255, 255)


def test_state_colors_are_distinct():
    darks = {state: colors["dark"] for state, colors in STATE_COLORS.items()}
    assert len(set(darks.values())) == len(darks)  # her durum farklı renk


def test_render_colored_image_size_and_pixels():
    qr, layout = _sample_layout()
    n = len(layout["sensor_modules"])
    assert n > 0

    img = render_colored_image(qr, layout, state="spoiled", scale=4, border=2)
    expected = (layout["matrix_size"] + 2 * 2) * 4
    assert img.size == (expected, expected)

    # ilk reaktif modülün merkez pikseli "spoiled" tonlarından biri olmalı
    r, c = layout["sensor_modules"][0]
    x = (c + 2) * 4 + 2
    y = (r + 2) * 4 + 2
    pixel = img.getpixel((x, y))
    assert pixel in (STATE_COLORS["spoiled"]["dark"], STATE_COLORS["spoiled"]["light"])


def test_save_synthetic_states(tmp_path):
    qr, layout = _sample_layout()
    paths = save_synthetic_states(qr, layout, tmp_path, stem="TEST123")
    assert set(paths) == {"fresh", "transition", "spoiled"}
    for p in paths.values():
        assert p.is_file()
        assert p.stat().st_size > 0
