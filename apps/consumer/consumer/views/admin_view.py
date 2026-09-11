"""Yönetici ekranı — GERÇEK üretici / etiket oluşturma formunu gösterir.

Kod tekrarı yok: `apps/producer/producer/app.py::build_form` aynı kartları
üretir; burada yalnızca kendi başlığımızla (geri oku) sarıyoruz. Üretici
uygulaması (apps/producer) bağımsız olarak da çalışmaya devam eder — aynı
fonksiyon iki giriş noktasından da kullanılır.
"""

import flet as ft

from consumer.profiles import load_layout_versions, load_sensor_profiles
from packages.ui_kit import theme as T
from packages.ui_kit.components import app_header, screen, stat_card
from producer.app import build_form as producer_form_cards


def admin_body(page: ft.Page, nav) -> ft.Control:
    profiles = load_sensor_profiles()
    layouts = load_layout_versions()

    stats = ft.Row(
        spacing=T.GAP_S,
        controls=[
            stat_card("Kalibrasyon profili", len(profiles)),
            stat_card("Etiket sürümü", len(layouts)),
        ],
    )

    return screen(
        app_header("Yönetici — Etiket Oluşturma", on_back=nav.login),
        stats,
        *producer_form_cards(page),
    )
