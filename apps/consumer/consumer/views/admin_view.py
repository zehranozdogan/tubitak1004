"""Basit yönetici sayfası — ortak sözleşme dosyalarını (profil/layout) okur ve gösterir.

Etiket / QR ÜRETİMİ ayrı üretici uygulamasındadır (apps/producer, rapor §8).
"""

import flet as ft

from packages.ui_kit import theme as T
from packages.ui_kit.components import app_header, kv, screen, section_card, stat_card
from consumer.profiles import example_files, load_layout_versions, load_sensor_profiles


def admin_body(page: ft.Page, nav) -> ft.Control:
    profiles = load_sensor_profiles()
    layouts = load_layout_versions()
    active_profile = profiles[0] if profiles else None
    active_layout = layouts[0] if layouts else None

    cards: list[ft.Control] = [
        ft.Row(
            spacing=T.GAP_S,
            controls=[
                stat_card("Kalibrasyon profili", len(profiles)),
                stat_card("Etiket sürümü", len(layouts)),
            ],
        )
    ]

    if active_profile is not None:
        cards.append(
            section_card(
                "Aktif kalibrasyon profili",
                kv("profile_id", active_profile["profile_id"]),
                kv("analyte_axis", active_profile["analyte_axis"]),
                kv("calibration_method", active_profile["calibration_method"]["code"]),
                kv("scale_points", len(active_profile["scale_points"])),
                kv(
                    "class_thresholds",
                    "tanımlı değil — teknik seviye gösterilir (§7.2)"
                    if active_profile.get("class_thresholds") is None
                    else "tanımlı",
                ),
            )
        )

    if active_layout is not None:
        cards.append(
            section_card(
                "Etiket sürümü (layout_version)",
                kv("layout_version", active_layout["layout_version"]),
                kv("qr_version", active_layout["qr_version"]),
                kv("matrix_size", active_layout["matrix_size"]),
                kv("module_density", active_layout["module_density"]),
                kv("sensor_modules", len(active_layout["sensor_modules"])),
            )
        )

    cards.append(
        section_card(
            "Etiket / QR üretimi",
            ft.Text(
                "Etiket üretimi ayrı üretici uygulamasındadır (rapor §8).",
                size=T.T_BODY,
                color=T.C_MUTED,
            ),
            ft.Text("flet run -w apps/producer/main.py", size=T.T_CAPTION, selectable=True),
        )
    )

    files = example_files()
    cards.append(
        section_card(
            "Profil & sürüm dosyaları",
            *(
                [ft.Text(f.name, size=T.T_CAPTION, color=T.C_MUTED) for f in files]
                or [ft.Text("Dosya bulunamadı.", size=T.T_CAPTION, color=T.C_MUTED)]
            ),
        )
    )

    return screen(app_header("Yönetici", on_back=nav.login), *cards)
