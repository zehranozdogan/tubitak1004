"""Tasarım tokenleri — tek yer. Ekranlarda çıplak sayı/renk kullanmayın."""

import flet as ft

SEED = "#00658F"

# Boşluk ölçeği
GAP_XS = 4
GAP_S = 8
GAP_M = 16
GAP_L = 24

RADIUS = 16
CONTENT_MAX_W = 480

# Yazı boyutları
T_TITLE = 26
T_HEADING = 18
T_BODY = 14
T_CAPTION = 12

# Anlamsal renkler (Material 3 token'ları — açık tema)
C_PRIMARY = ft.Colors.PRIMARY
C_ON_PRIMARY = ft.Colors.ON_PRIMARY
C_MUTED = ft.Colors.ON_SURFACE_VARIANT
C_OUTLINE = ft.Colors.OUTLINE_VARIANT
C_PAGE_BG = ft.Colors.SURFACE_CONTAINER
C_HEADER_BG = ft.Colors.PRIMARY_CONTAINER
C_ON_HEADER = ft.Colors.ON_PRIMARY_CONTAINER
C_ACCENT_BG = ft.Colors.SECONDARY_CONTAINER

# Tazelik durum renkleri (rapor §7 — yalnızca doğrulanmış eşik varsa gösterilir)
C_FRESH = ft.Colors.GREEN
C_TRANSITION = ft.Colors.ORANGE
C_SPOILED = ft.Colors.RED


def apply_page(page) -> None:
    """Sayfa temasını prototiplerde tek satırda kurar."""
    page.theme = ft.Theme(color_scheme_seed=SEED)
    page.theme_mode = ft.ThemeMode.LIGHT
    page.bgcolor = C_PAGE_BG
    page.padding = 0
