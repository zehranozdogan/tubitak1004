"""Giriş — parola YOK. Yönetici / Kullanıcı seç, ilgili ekrana geç."""

import flet as ft

from packages.ui_kit import theme as T
from packages.ui_kit.components import icon_badge, nav_tile


def login_body(page: ft.Page, nav) -> ft.Control:
    card = ft.Card(
        elevation=2,
        content=ft.Container(
            width=T.CONTENT_MAX_W,
            padding=T.GAP_L,
            content=ft.Column(
                horizontal_alignment=ft.CrossAxisAlignment.STRETCH,
                spacing=T.GAP_S,
                controls=[
                    ft.Row(
                        [icon_badge(ft.Icons.ECO, 34)],
                        alignment=ft.MainAxisAlignment.CENTER,
                    ),
                    ft.Text(
                        "FreshQR",
                        size=T.T_TITLE,
                        weight=ft.FontWeight.BOLD,
                        text_align=ft.TextAlign.CENTER,
                    ),
                    ft.Text(
                        "Balık tazeliği — QR sensör etiketi okuyucu",
                        size=T.T_BODY,
                        color=T.C_MUTED,
                        text_align=ft.TextAlign.CENTER,
                    ),
                    ft.Container(height=T.GAP_M),
                    nav_tile(
                        "Yönetici",
                        "Kalibrasyon profili ve etiket sürümü",
                        ft.Icons.ADMIN_PANEL_SETTINGS,
                        nav.admin,
                    ),
                    nav_tile(
                        "Kullanıcı",
                        "Etiket tara, tazelik sonucu gör",
                        ft.Icons.QR_CODE_SCANNER,
                        nav.user,
                    ),
                    ft.Container(height=T.GAP_XS),
                    ft.Text(
                        "Prototip — parola istenmez.",
                        size=T.T_CAPTION,
                        color=T.C_MUTED,
                        text_align=ft.TextAlign.CENTER,
                    ),
                ],
            ),
        ),
    )

    return ft.Container(
        expand=True,
        bgcolor=T.C_PAGE_BG,
        padding=T.GAP_M,
        content=ft.Column(
            [ft.Row([card], alignment=ft.MainAxisAlignment.CENTER)],
            expand=True,
            scroll=ft.ScrollMode.AUTO,
            alignment=ft.MainAxisAlignment.CENTER,
            horizontal_alignment=ft.CrossAxisAlignment.CENTER,
        ),
    )
