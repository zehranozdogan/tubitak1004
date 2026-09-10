"""Kullanıcı sayfası — İSKELET.

Arkadaş bu ekranı geliştirecek. Aynı tasarım sistemi: consumer/theme.py + consumer/components.py.
Tarama akışı (rapor §7): kamera → QR decode → profile/layout yükle → color_engine.analyze() → sonuç.
Sonuç kuralı (§7.2): bilimsel eşik yoksa "taze/geçiş/bozuk" GÖSTERME; teknik seviye göster.
"""

import flet as ft

from packages.ui_kit import theme as T
from packages.ui_kit.components import app_header, screen, section_card


def user_body(page: ft.Page, nav) -> ft.Control:
    info = ft.Text("", size=T.T_CAPTION, color=T.C_PRIMARY)

    def on_scan(_e) -> None:
        info.value = (
            "Tarama akışı bu ekranda geliştirilecek: kamera → QR decode → "
            "profil/layout yükle → color_engine.analyze() → sonuç."
        )
        page.update()

    scan_button = ft.FilledTonalButton(
        height=120,
        on_click=on_scan,
        content=ft.Row(
            alignment=ft.MainAxisAlignment.CENTER,
            spacing=T.GAP_S,
            controls=[
                ft.Icon(ft.Icons.QR_CODE_SCANNER, size=26),
                ft.Text("Etiket Tara", size=T.T_HEADING),
            ],
        ),
    )

    return screen(
        app_header("Tazelik", on_back=nav.login),
        scan_button,
        info,
        section_card("Son okumalar", ft.Text("Henüz okuma yok.", color=T.C_MUTED, size=T.T_BODY)),
    )
