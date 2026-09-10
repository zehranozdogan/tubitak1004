"""Tüketici prototipi — tek sayfa, içerik değişimi (Flet 0.86 uyumlu, routing yok)."""

import flet as ft

from packages.ui_kit import theme as T
from consumer.views.admin_view import admin_body
from consumer.views.login_view import login_body
from consumer.views.user_view import user_body


class _Nav:
    def __init__(self, render):
        self._render = render

    def login(self):
        self._render(login_body)

    def admin(self):
        self._render(admin_body)

    def user(self):
        self._render(user_body)


def main(page: ft.Page) -> None:
    page.title = "FreshQR — Prototip"
    T.apply_page(page)

    root = ft.Container(expand=True, bgcolor=T.C_PAGE_BG)
    page.add(root)

    def render(builder) -> None:
        root.content = builder(page, nav)
        page.update()

    nav = _Nav(render)
    render(login_body)
