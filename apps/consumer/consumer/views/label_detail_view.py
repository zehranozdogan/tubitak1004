"""Tek bir üretilmiş etiketin detayı — bilgileri + 3 tazelik durumunun renkli QR'ları."""

from __future__ import annotations

import base64
import json
from pathlib import Path

import flet as ft

from consumer.labels import OUT_DIR, delete_label
from packages.qr_layout.colors import STATE_LABELS
from packages.ui_kit import theme as T
from packages.ui_kit.components import app_header, kv, screen, section_card


def _read_json(path: Path) -> dict:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}


def _state_image(stem: str, state_key: str, label: str) -> ft.Control:
    png_path = OUT_DIR / f"{stem}.state_{state_key}.png"
    if png_path.is_file():
        b64 = base64.b64encode(png_path.read_bytes()).decode()
        inner: ft.Control = ft.Image(src=b64, fit=ft.BoxFit.CONTAIN)
    else:
        inner = ft.Text("Yok", size=T.T_CAPTION, color=T.C_MUTED)

    frame = ft.Container(
        content=inner,
        width=150,
        height=150,
        bgcolor=ft.Colors.WHITE,
        border=ft.Border.all(1, T.C_OUTLINE),
        border_radius=T.RADIUS,
        padding=T.GAP_S,
        alignment=ft.Alignment(0, 0),
    )
    return ft.Column(
        spacing=4,
        horizontal_alignment=ft.CrossAxisAlignment.CENTER,
        controls=[frame, ft.Text(label, size=T.T_CAPTION, color=T.C_MUTED)],
    )


def _confirm_delete(page: ft.Page, nav, stem: str, product_id: str) -> None:
    def do_delete(_e) -> None:
        page.pop_dialog()
        delete_label(stem)
        nav.labels()

    def cancel(_e) -> None:
        page.pop_dialog()

    dialog = ft.AlertDialog(
        modal=True,
        title=ft.Text("Etiketi sil"),
        content=ft.Text(
            f'"{product_id}" etiketi ve tüm dosyaları (PNG, PDF, JSON, 3 tazelik '
            "görseli) kalıcı olarak silinecek. Bu geri alınamaz."
        ),
        actions=[
            ft.TextButton("Vazgeç", on_click=cancel),
            ft.TextButton(
                "Sil", on_click=do_delete, style=ft.ButtonStyle(color=ft.Colors.RED)
            ),
        ],
        actions_alignment=ft.MainAxisAlignment.END,
    )
    page.show_dialog(dialog)


def label_detail_body(page: ft.Page, nav, stem: str) -> ft.Control:
    payload = _read_json(OUT_DIR / f"{stem}.label_payload.json")
    layout = _read_json(OUT_DIR / f"{stem}.layout_version.json")
    product_id = payload.get("product_id", stem)

    info_card = section_card(
        "Etiket bilgisi",
        kv("Parti no", payload.get("product_id", "—")),
        kv("Ürün türü", payload.get("product_type", "—")),
        kv("Üretim tarihi", payload.get("production_date", "—")),
        kv("sensor_profile_id", payload.get("sensor_profile_id", "—")),
        kv("layout_version", payload.get("layout_version", "—")),
    )

    layout_card = section_card(
        "Layout bilgisi",
        kv("QR versiyonu", f"v{layout.get('qr_version', '—')}"),
        kv("Matris", layout.get("matrix_size", "—")),
        kv("Reaktif modül", len(layout.get("sensor_modules", []))),
        kv("Yoğunluk", layout.get("module_density", "—")),
    )

    states_card = section_card(
        "Tazelik durumları (§8: sentetik görseller)",
        ft.Row(
            spacing=T.GAP_M,
            alignment=ft.MainAxisAlignment.CENTER,
            wrap=True,
            controls=[_state_image(stem, key, label) for key, label in STATE_LABELS.items()],
        ),
    )

    delete_button = ft.IconButton(
        ft.Icons.DELETE_OUTLINE,
        icon_color=T.C_ON_HEADER,
        tooltip="Etiketi sil",
        on_click=lambda e: _confirm_delete(page, nav, stem, product_id),
    )

    return screen(
        app_header(product_id, on_back=nav.labels, actions=[delete_button]),
        info_card,
        layout_card,
        states_card,
    )
