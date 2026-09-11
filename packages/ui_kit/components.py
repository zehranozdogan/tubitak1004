"""Yeniden kullanılabilir UI parçaları (apps/consumer prototipi için)."""

from __future__ import annotations

import flet as ft

from packages.ui_kit import theme as T

_CENTER = ft.Alignment(0, 0)


def icon_badge(icon, size: int = 24) -> ft.Control:
    return ft.Container(
        content=ft.Icon(icon, size=size, color=T.C_ON_PRIMARY),
        bgcolor=T.C_PRIMARY,
        border_radius=999,
        padding=T.GAP_S,
        alignment=_CENTER,
    )


def app_header(title: str, on_back=None) -> ft.Control:
    row: list[ft.Control] = []
    if on_back is not None:
        row.append(
            ft.IconButton(ft.Icons.ARROW_BACK, icon_color=T.C_ON_HEADER, on_click=lambda e: on_back())
        )
    row.append(ft.Text(title, size=T.T_HEADING, weight=ft.FontWeight.W_600, color=T.C_ON_HEADER))
    return ft.Container(
        bgcolor=T.C_HEADER_BG,
        padding=ft.Padding(left=8, top=10, right=16, bottom=10),
        content=ft.Row(row, spacing=4, vertical_alignment=ft.CrossAxisAlignment.CENTER),
    )


def screen(header: ft.Control, *body: ft.Control, max_width: int | None = None) -> ft.Control:
    inner = ft.Column(
        list(body),
        spacing=T.GAP_M,
        width=max_width or T.CONTENT_MAX_W,
        horizontal_alignment=ft.CrossAxisAlignment.STRETCH,
    )
    scroll_area = ft.Column(
        [ft.Row([inner], alignment=ft.MainAxisAlignment.CENTER)],
        scroll=ft.ScrollMode.AUTO,
        expand=True,
    )
    return ft.Column(
        [header, ft.Container(content=scroll_area, expand=True, padding=T.GAP_M)],
        spacing=0,
        expand=True,
    )


def section_card(title: str, *controls: ft.Control) -> ft.Control:
    return ft.Card(
        elevation=1,
        content=ft.Container(
            padding=T.GAP_M,
            content=ft.Column(
                [ft.Text(title, size=T.T_HEADING, weight=ft.FontWeight.W_600), *controls],
                spacing=T.GAP_S,
            ),
        ),
    )


def kv(label: str, value) -> ft.Control:
    return ft.Row(
        alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
        controls=[
            ft.Text(label, color=T.C_MUTED, size=T.T_BODY),
            ft.Text(str(value), size=T.T_BODY, weight=ft.FontWeight.W_500),
        ],
    )


def stat_card(label: str, value) -> ft.Control:
    return ft.Card(
        elevation=1,
        expand=True,
        content=ft.Container(
            padding=T.GAP_M,
            content=ft.Column(
                [
                    ft.Text(str(value), size=T.T_TITLE, weight=ft.FontWeight.BOLD, color=T.C_PRIMARY),
                    ft.Text(label, size=T.T_CAPTION, color=T.C_MUTED),
                ],
                spacing=T.GAP_XS,
            ),
        ),
    )


def nav_tile(title: str, subtitle: str, icon, on_click) -> ft.Control:
    return ft.Container(
        padding=T.GAP_M,
        border_radius=T.RADIUS,
        border=ft.Border.all(1, T.C_OUTLINE),
        ink=True,
        on_click=lambda e: on_click(),
        content=ft.Row(
            spacing=T.GAP_M,
            vertical_alignment=ft.CrossAxisAlignment.CENTER,
            controls=[
                icon_badge(icon, 22),
                ft.Column(
                    [
                        ft.Text(title, size=T.T_HEADING, weight=ft.FontWeight.W_600),
                        ft.Text(subtitle, size=T.T_CAPTION, color=T.C_MUTED),
                    ],
                    spacing=2,
                    expand=True,
                ),
                ft.Icon(ft.Icons.CHEVRON_RIGHT, color=T.C_MUTED),
            ],
        ),
    )


def text_field(label: str, value: str = "") -> ft.TextField:
    return ft.TextField(label=label, value=value, filled=True, border_radius=T.RADIUS)


def primary_button(text: str, on_click, icon=None) -> ft.Control:
    return ft.FilledButton(text, icon=icon, on_click=on_click)
