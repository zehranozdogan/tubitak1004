"""Üretici arayüzü (Flet). Tüketici prototipiyle aynı tasarım sistemi (packages/ui_kit).

Rapor §3.2: üretici tarafı web/desktop olabilir.
"""

from __future__ import annotations

import base64
import json
from datetime import date
from pathlib import Path

import flet as ft

from packages.qr_layout import generate_qr
from packages.qr_layout.render import png_bytes
from packages.ui_kit import theme as T
from packages.ui_kit.components import app_header, kv, primary_button, screen, section_card, text_field
from producer.export import build_label_payload, export_label

OUT_DIR = Path("out")


def build_view(page: ft.Page) -> ft.Control:
    product_type = text_field("Ürün türü", "LEVREK")
    product_id = text_field("Parti / Lot no", "TR45678")
    production_date = text_field("Üretim tarihi (YYYY-AA-GG)", date.today().isoformat())
    sensor_profile_id = text_field("sensor_profile_id", "GENIPIN_PUTRESIN_v2")
    layout_version = text_field("layout_version", "QR_SENSOR_v4")
    density = ft.Dropdown(
        label="Layout yoğunluğu (§8: 3 aday)",
        value="low",
        filled=True,
        border_radius=T.RADIUS,
        options=[ft.dropdown.Option("low"), ft.dropdown.Option("medium"), ft.dropdown.Option("high")],
    )

    preview = ft.Image(src="", width=220, height=220, fit=ft.BoxFit.CONTAIN)
    status = ft.Text("", size=T.T_CAPTION, color=T.C_MUTED)
    files_col = ft.Column(spacing=2)
    meta_col = ft.Column(spacing=T.GAP_S)

    def _payload() -> dict:
        return build_label_payload(
            product_id.value,
            product_type.value,
            production_date.value,
            sensor_profile_id.value,
            layout_version.value,
        )

    def do_preview(_e=None) -> None:
        try:
            payload = _payload()
            qr = generate_qr(json.dumps(payload, ensure_ascii=False, separators=(",", ":")), error="h")
        except Exception as ex:  # noqa: BLE001 - kullanıcıya göster
            status.value = f"Geçersiz girdi: {ex}"
            page.update()
            return
        preview.src_base64 = base64.b64encode(png_bytes(qr, scale=6)).decode()
        n = 4 * qr.version + 17
        meta_col.controls = [
            kv("QR versiyonu", f"v{qr.version}"),
            kv("Modül", f"{n} × {n}"),
            kv("ECC", "H"),
        ]
        status.value = "Önizleme hazır. 'Etiketi oluştur' ile dosyaları üret."
        page.update()

    def do_export(_e) -> None:
        try:
            payload = _payload()
            result = export_label(payload, OUT_DIR, density=density.value or "low")
        except Exception as ex:  # noqa: BLE001
            status.value = f"Hata: {ex}"
            page.update()
            return
        preview.src_base64 = base64.b64encode(png_bytes(result["qr"], scale=6)).decode()
        layout = result["layout"]
        meta_col.controls = [
            kv("QR versiyonu", f"v{result['qr'].version}"),
            kv("Matris", layout["matrix_size"]),
            kv("Reaktif modül", len(layout["sensor_modules"])),
            kv("Yoğunluk", layout["module_density"]),
        ]
        files_col.controls = [
            ft.Text(str(p), size=T.T_CAPTION, color=T.C_MUTED, selectable=True)
            for p in result["paths"].values()
        ]
        status.value = f"Dosyalar '{OUT_DIR}/' altına yazıldı."
        page.update()

    do_preview()

    form = section_card(
        "Etiket bilgisi",
        product_type,
        product_id,
        production_date,
        sensor_profile_id,
        layout_version,
        density,
        ft.Row(
            spacing=T.GAP_S,
            controls=[
                ft.OutlinedButton("Önizle", on_click=do_preview),
                primary_button("Etiketi oluştur", do_export, ft.Icons.QR_CODE_2),
            ],
        ),
        status,
    )

    preview_card = section_card(
        "Etiket önizleme",
        ft.Row([preview], alignment=ft.MainAxisAlignment.CENTER),
        meta_col,
        ft.Text("Çıktı dosyaları", size=T.T_CAPTION, weight=ft.FontWeight.W_600, color=T.C_MUTED),
        files_col,
    )

    note = ft.Container(
        bgcolor=T.C_ACCENT_BG,
        border_radius=T.RADIUS,
        padding=T.GAP_M,
        content=ft.Text(
            "Reaktif hücreler QR veri alanına DAĞITILIR (merkez sensör yok, §5). "
            "Renkli gösterim + sentetik taze/geçiş/bozulma görselleri: qr_layout.render TODO.",
            size=T.T_CAPTION,
            color=T.C_MUTED,
        ),
    )

    return screen(app_header("Üretici — Etiket Oluşturma"), form, preview_card, note)
