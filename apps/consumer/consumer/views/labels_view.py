"""Üretilen etiketler listesi — out/ altındaki her *.label_payload.json için
bir kart: küçük QR görseli + temel bilgiler."""

from __future__ import annotations

import base64

import flet as ft

from consumer.labels import OUT_DIR, load_labels
from packages.ui_kit import theme as T
from packages.ui_kit.components import app_header, screen


def _thumbnail(stem: str) -> ft.Control:
    png_path = OUT_DIR / f"{stem}.png"
    if not png_path.is_file():
        return ft.Container(
            width=64, height=64, bgcolor=T.C_PAGE_BG, border_radius=8,
            alignment=ft.Alignment(0, 0),
            content=ft.Icon(ft.Icons.QR_CODE_2, color=T.C_MUTED, size=28),
        )
    b64 = base64.b64encode(png_path.read_bytes()).decode()
    return ft.Container(
        width=64, height=64, bgcolor=ft.Colors.WHITE, border_radius=8,
        border=ft.Border.all(1, T.C_OUTLINE), padding=4,
        content=ft.Image(src=b64, fit=ft.BoxFit.CONTAIN),
    )


def _label_card(label: dict, nav) -> ft.Control:
    card = ft.Card(
        elevation=1,
        shape=ft.RoundedRectangleBorder(radius=T.RADIUS),
        bgcolor=ft.Colors.WHITE,
        content=ft.Container(
            padding=T.GAP_M,
            content=ft.Row(
                spacing=T.GAP_M,
                vertical_alignment=ft.CrossAxisAlignment.CENTER,
                controls=[
                    _thumbnail(label["_stem"]),
                    ft.Column(
                        spacing=2,
                        expand=True,
                        controls=[
                            ft.Text(
                                f"{label['product_id']} · {label['product_type']}",
                                size=T.T_BODY,
                                weight=ft.FontWeight.W_600,
                            ),
                            ft.Text(
                                f"{label['production_date']}",
                                size=T.T_CAPTION,
                                color=T.C_MUTED,
                            ),
                            ft.Text(
                                f"{label['sensor_profile_id']} · {label['layout_version']}",
                                size=T.T_CAPTION,
                                color=T.C_MUTED,
                            ),
                        ],
                    ),
                    ft.Icon(ft.Icons.CHEVRON_RIGHT, color=T.C_MUTED),
                ],
            ),
        ),
    )
    # Card kendi on_click'i yok; tıklamayı yakalamak için Container'a sarıyoruz
    # (bkz. packages/ui_kit/components.py::nav_tile ile aynı desen).
    return ft.Container(
        content=card,
        border_radius=T.RADIUS,
        ink=True,
        on_click=lambda e: nav.label_detail(label["_stem"]),
    )


def labels_body(page: ft.Page, nav) -> ft.Control:
    labels = load_labels()

    body: list[ft.Control] = (
        [_label_card(label, nav) for label in labels]
        if labels
        else [
            ft.Text(
                "Henüz etiket üretilmedi. Yönetici ekranında 'Etiketi oluştur' ile ilk etiketini üret.",
                size=T.T_BODY,
                color=T.C_MUTED,
            )
        ]
    )

    return screen(
        app_header(f"Üretilen Etiketler ({len(labels)})", on_back=nav.admin),
        *body,
    )
