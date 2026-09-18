"""Yönetici ekranı — etiket oluşturma (rapor §8).

Ayrı bir üretici uygulaması YOK; tek çalışan uygulama apps/consumer'dır.
İş mantığı framework'ten bağımsız (packages/label_export, packages/qr_layout),
bu yüzden ileride gerekirse ayrı bir üretici arayüzü kolayca eklenebilir.
"""

from __future__ import annotations

import base64
import json
from datetime import date, datetime
from pathlib import Path

import flet as ft

from consumer.labels import OUT_DIR, count_labels
from consumer.profiles import load_layout_versions, load_sensor_profiles
from packages.label_export import build_label_payload, export_label
from packages.qr_layout import (
    build_layout,
    generate_qr,
    reactive_candidates,
    seed_from_layout_version,
    select_reactive_modules,
)
from packages.qr_layout.colors import STATE_LABELS
from packages.qr_layout.render import label_png_bytes
from packages.ui_kit import theme as T
from packages.ui_kit.components import (
    app_header,
    dropdown_field,
    kv,
    outlined_button,
    primary_button,
    screen,
    section_card,
    stat_card,
    stat_card_live,
    text_field,
)

# İlk tür listesi (prototip) — dropdown_field editable=True olduğu için listede
# olmayan bir tür de elle yazılabilir. İleride profile'dan türetilebilir.
COMMON_SPECIES = ["LEVREK", "ÇİPURA", "SOMON", "ALABALIK"]

_BATCH_PREFIX = "TR"
_BATCH_START = 45678  # rapor örneğindeki ilk parti no (§8, §10.1: "TR45678")


def _next_batch_no(out_dir: Path) -> str:
    """out/ altındaki mevcut etiketleri tarayıp bir sonraki sıralı parti
    numarasını üretir. Üretici parti no'yu elle girmez.

    DB SEÇİMİ (bkz. docs/decisions/0003-database-placeholder.md): bu, dosya
    tabanlı geçici bir sayaçtır. DB bağlanınca burası bir "batches" tablosuna
    sorgu (MAX(no)+1 veya otomatik artan sütun) ile değişecek; imza (-> str)
    aynı kalırsa çağıran kod (admin_body) değişmeden geçiş yapılabilir.
    """
    used = []
    if out_dir.exists():
        for f in out_dir.glob(f"{_BATCH_PREFIX}*.label_payload.json"):
            digits = f.name[len(_BATCH_PREFIX):].split("_", 1)[0]
            if digits.isdigit():
                used.append(int(digits))
    return f"{_BATCH_PREFIX}{(max(used) + 1) if used else _BATCH_START}"


def _to_iso_date(value: str) -> str:
    """Girdideki GG.AA.YYYY'yi label_payload sözleşmesinin (§10.1) beklediği
    ISO (YYYY-AA-GG) formatına çevirir. Ayrıştırılamazsa girdiyi olduğu gibi
    döndürür; build_label_payload zaten geçersiz değeri kullanıcıya bildirir.
    """
    value = (value or "").strip()
    try:
        return datetime.strptime(value, "%d.%m.%Y").date().isoformat()
    except ValueError:
        return value


def admin_body(page: ft.Page, nav) -> ft.Control:
    profiles = load_sensor_profiles()
    layouts = load_layout_versions()

    def _selected_profile(profile_id: str) -> dict | None:
        # Seçili sensor_profile_id'nin GERÇEK dosyasını bulur (sadece ID
        # string'i değil) — render_label_image bunun calibration_method.code'una
        # bakıp gerekiyorsa referans yaması (§6.1 B/C) basar. Bulunamazsa None
        # (render_label_image bunu QR-içi/A-D varsayılanına düşürür).
        return next((p for p in profiles if p.get("profile_id") == profile_id), None)

    label_count_card, label_count_text = stat_card_live(
        "Üretilen etiket", count_labels(OUT_DIR)
    )
    label_count_clickable = ft.Container(
        content=label_count_card,
        expand=True,
        border_radius=T.RADIUS,
        ink=True,
        tooltip="Üretilen etiketlere bak",
        on_click=lambda e: nav.labels(),
    )
    stats = ft.Row(
        spacing=T.GAP_S,
        controls=[
            stat_card("Kalibrasyon profili", len(profiles)),
            stat_card("Etiket sürümü", len(layouts)),
            label_count_clickable,
        ],
    )

    product_type = dropdown_field(
        "Ürün türü", "LEVREK", COMMON_SPECIES, icon=ft.Icons.SET_MEAL, editable=True
    )

    product_id = text_field("Parti / Lot no (otomatik)", _next_batch_no(OUT_DIR), icon=ft.Icons.TAG)
    product_id.read_only = True
    product_id.expand = True

    def regenerate_batch_no(_e=None) -> None:
        # Diskten yeniden taramak, iki tıklama arasında hiçbir şey
        # değişmediyse AYNI sayıyı verir (görünürde "çalışmıyor" gibi
        # durur). Bunun yerine ekrandaki mevcut sayıyı 1 artır; ilk
        # değeri hâlâ _next_batch_no ile diskten güvenli başlatıyoruz.
        try:
            current = int((product_id.value or "").removeprefix(_BATCH_PREFIX))
            product_id.value = f"{_BATCH_PREFIX}{current + 1}"
        except ValueError:
            product_id.value = _next_batch_no(OUT_DIR)
        page.update()

    production_date = text_field(
        "Üretim tarihi (GG.AA.YYYY)", date.today().strftime("%d.%m.%Y"), icon=ft.Icons.CALENDAR_MONTH
    )
    production_date.expand = True

    def reset_production_date(_e=None) -> None:
        production_date.value = date.today().strftime("%d.%m.%Y")
        page.update()

    production_date_row = ft.Row(
        spacing=T.GAP_S,
        vertical_alignment=ft.CrossAxisAlignment.CENTER,
        controls=[
            production_date,
            ft.IconButton(ft.Icons.TODAY, tooltip="Bugüne sıfırla", on_click=reset_production_date),
        ],
    )

    # packages/profile_schema/examples/ altında GERÇEKTEN var olan profil/sürümlerden
    # gelir — elle hatırlanıp yazılan sabit bir metin değil.
    profile_ids = [p["profile_id"] for p in profiles] or ["GENIPIN_PUTRESIN_v2"]
    layout_ids = [lv["layout_version"] for lv in layouts] or ["QR_SENSOR_v4"]

    sensor_profile_id = dropdown_field(
        "sensor_profile_id", profile_ids[0], profile_ids, icon=ft.Icons.SCIENCE, editable=True
    )
    layout_version = dropdown_field(
        "layout_version", layout_ids[0], layout_ids, icon=ft.Icons.GRID_VIEW, editable=True
    )
    density = dropdown_field(
        "Layout yoğunluğu", "low", ["low", "medium", "high"], icon=ft.Icons.TUNE
    )

    status = ft.Text("", size=T.T_CAPTION, color=T.C_MUTED)
    files_col = ft.Column(spacing=2)
    meta_col = ft.Column(spacing=T.GAP_S)
    state_previews_row = ft.Row(spacing=T.GAP_S, alignment=ft.MainAxisAlignment.CENTER, wrap=True)

    def _payload() -> dict:
        return build_label_payload(
            product_id.value,
            product_type.value,
            _to_iso_date(production_date.value),
            sensor_profile_id.value,
            layout_version.value,
        )

    def do_preview(_e=None) -> None:
        preview_card.visible = True
        try:
            payload = _payload()
            qr = generate_qr(json.dumps(payload, ensure_ascii=False, separators=(",", ":")), error="h")
            modules = select_reactive_modules(
                reactive_candidates(qr),
                density=density.value or "low",
                seed=seed_from_layout_version(layout_version.value or ""),
            )
            layout = build_layout(
                qr, modules, layout_version=layout_version.value, density=density.value or "low"
            )
        except Exception as ex:  # noqa: BLE001 - kullanıcıya göster
            status.value = f"Geçersiz girdi: {ex}"
            page.update()
            return
        sensor_profile = _selected_profile(sensor_profile_id.value)
        # Nötr gri = reaktif hücrelerin yerleşimi; henüz bir tazelik durumu değil.
        # label_png_bytes: sensor_profile'ın kalibrasyon yöntemi (§6.1 B/C) ek
        # referans yaması istiyorsa önizlemede de gösterir — gerçek çıktıyla aynı.
        preview_frame.content = ft.Image(
            src=base64.b64encode(label_png_bytes(qr, layout, sensor_profile, state=None)).decode(),
            fit=ft.BoxFit.CONTAIN,
        )
        n = 4 * qr.version + 17
        calibration_code = ((sensor_profile or {}).get("calibration_method") or {}).get("code", "white_black")
        meta_col.controls = [
            kv("Parti no", payload["product_id"]),
            kv("QR versiyonu", f"v{qr.version}"),
            kv("Modül", f"{n} × {n}"),
            kv("Reaktif modül", len(modules)),
            kv("ECC", "H"),
            kv("Kalibrasyon", calibration_code),
        ]
        status.value = "Gri noktalar = reaktif sensör hücreleri. 'Etiketi oluştur' ile dosyaları üret."
        page.update()

    def do_export(_e) -> None:
        preview_card.visible = True
        sensor_profile = _selected_profile(sensor_profile_id.value)
        try:
            payload = _payload()
            result = export_label(
                payload, OUT_DIR, density=density.value or "low", sensor_profile=sensor_profile
            )
        except Exception as ex:  # noqa: BLE001
            status.value = f"Hata: {ex}"
            page.update()
            return
        qr, layout = result["qr"], result["layout"]
        preview_frame.content = ft.Image(
            src=base64.b64encode(label_png_bytes(qr, layout, sensor_profile, state=None)).decode(),
            fit=ft.BoxFit.CONTAIN,
        )
        calibration_code = ((sensor_profile or {}).get("calibration_method") or {}).get("code", "white_black")
        meta_col.controls = [
            kv("Parti no", payload["product_id"]),
            kv("QR versiyonu", f"v{qr.version}"),
            kv("Matris", layout["matrix_size"]),
            kv("Reaktif modül", len(layout["sensor_modules"])),
            kv("Yoğunluk", layout["module_density"]),
            kv("Kalibrasyon", calibration_code),
        ]
        def _state_thumb(state_key: str, label: str) -> ft.Control:
            # Bu Flet sürümünde ayrı bir src_base64 alanı yok; base64 metni
            # doğrudan src'ye yazılır (bkz. ft.Image docstring: "A base64 string").
            b64 = base64.b64encode(
                label_png_bytes(qr, layout, sensor_profile, state=state_key, scale=8, border=1)
            ).decode()
            img = ft.Image(src=b64, width=130, height=130, fit=ft.BoxFit.CONTAIN)
            return ft.Column(
                spacing=2,
                horizontal_alignment=ft.CrossAxisAlignment.CENTER,
                controls=[img, ft.Text(label, size=T.T_CAPTION, color=T.C_MUTED)],
            )

        state_previews_row.controls = [
            _state_thumb(state_key, label) for state_key, label in STATE_LABELS.items()
        ]
        files_col.controls = [
            ft.Text(str(p), size=T.T_CAPTION, color=T.C_MUTED, selectable=True)
            for p in result["paths"].values()
        ]
        status.value = f"Dosyalar '{OUT_DIR}/' altına yazıldı."
        label_count_text.value = str(count_labels(OUT_DIR))
        regenerate_batch_no()  # bir sonraki etiket için parti no'yu ilerlet (page.update() içinde)

    product_id_row = ft.Row(
        spacing=T.GAP_S,
        vertical_alignment=ft.CrossAxisAlignment.CENTER,
        controls=[
            product_id,
            ft.IconButton(
                ft.Icons.REFRESH,
                tooltip="Yeni parti no üret",
                on_click=regenerate_batch_no,
            ),
        ],
    )

    fields = ft.Column(
        spacing=T.GAP_L,
        horizontal_alignment=ft.CrossAxisAlignment.STRETCH,
        controls=[
            product_type,
            product_id_row,
            production_date_row,
            sensor_profile_id,
            layout_version,
            density,
            ft.Row(
                spacing=T.GAP_S,
                controls=[
                    outlined_button("Önizle", do_preview, ft.Icons.VISIBILITY),
                    primary_button("Etiketi oluştur", do_export, ft.Icons.QR_CODE_2),
                ],
            ),
        ],
    )

    form = section_card("Etiket bilgisi", fields)

    preview_frame = ft.Container(
        content=ft.Column(
            spacing=T.GAP_XS,
            horizontal_alignment=ft.CrossAxisAlignment.CENTER,
            controls=[
                ft.Icon(ft.Icons.QR_CODE_2, color=T.C_MUTED, size=48),
                ft.Text("Önizlemek için 'Önizle'ye bas", size=T.T_CAPTION, color=T.C_MUTED),
            ],
        ),
        width=280,
        height=280,
        bgcolor=ft.Colors.WHITE,
        border=ft.Border.all(1, T.C_OUTLINE),
        border_radius=T.RADIUS,
        padding=T.GAP_M,
        alignment=ft.Alignment(0, 0),
    )

    preview_card = section_card(
        "Etiket önizleme",
        ft.Text(
            "Girdiğin bilgilere göre oluşacak QR'ın canlı önizlemesi — henüz "
            "hiçbir dosya kaydedilmedi. Gri noktalar reaktif sensör hücrelerinin "
            "yerleşimini gösterir (henüz bir tazelik durumu değil).",
            size=T.T_CAPTION,
            color=T.C_MUTED,
        ),
        ft.Row([preview_frame], alignment=ft.MainAxisAlignment.CENTER),
        status,
        meta_col,
        ft.Text(
            "Sentetik durumlar (§8) — 'Etiketi oluştur' sonrası dolar",
            size=T.T_CAPTION,
            weight=ft.FontWeight.W_600,
            color=T.C_MUTED,
        ),
        state_previews_row,
        ft.Text("Çıktı dosyaları", size=T.T_CAPTION, weight=ft.FontWeight.W_600, color=T.C_MUTED),
        files_col,
    )
    # 'Önizle' veya 'Etiketi oluştur'a basılana kadar kart tamamen gizli.
    preview_card.visible = False

    note = ft.Container(
        bgcolor=T.C_ACCENT_BG,
        border_radius=T.RADIUS,
        padding=T.GAP_M,
        content=ft.Text(
            "Reaktif hücreler QR veri alanına DAĞITILIR (merkez sensör yok, §5). "
            "Her modülün rengi kendi açık/koyu (0/1) sınıfını korur ki QR hâlâ "
            "okunabilsin (§5.2) — gerçek pigment renkleri deney verisiyle kalibre edilecek.",
            size=T.T_CAPTION,
            color=T.C_MUTED,
        ),
    )

    return screen(
        app_header("Yönetici — Etiket Oluşturma", on_back=nav.login),
        stats,
        form,
        preview_card,
        note,
    )
