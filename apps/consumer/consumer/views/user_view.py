"""Kullanıcı sayfası — tarama + sonuç akışı (rapor §7).

Akış: Tarama ekranı (kamera henüz yok, buton simüle eder) → Yükleniyor →
Sonuç ekranı. Veri şimdilik mock; gerçek entegrasyonda `_run_scan` içindeki
mock sonuç yerine `packages.color_engine.pipeline.analyze()` çağrılacak —
ColorEngineResult şekli burada da kullanılıyor ki geçiş kod değişikliği
gerektirmesin.

Sonuç ekranı kuralı (§7.2, kritik):
- `rescan_recommended` ise sınıf/seviye GÖSTERME, "Yeniden tara" göster.
- `freshness_class` yoksa (bilimsel eşik tanımlı değilse) "Taze/Geçiş/Bozuk"
  UYDURMA; `technical_level` göster. Eşik tanımlandığında kod değişmeden
  `freshness_class` dolu gelir ve üstteki dal otomatik devreye girer.
"""

from __future__ import annotations

import asyncio

import flet as ft

from packages.color_engine.types import ColorEngineResult
from packages.ui_kit import theme as T
from packages.ui_kit.components import app_header, kv, screen, section_card

_MOCK_LABEL_INFO = {
    "product_type": "Levrek",
    "product_id": "TR45678",
}

_MOCK_OK = ColorEngineResult(
    quality_score=0.86,
    rescan_recommended=False,
    technical_level="Renk seviyesi 2 / Profil noktası P4",
    confidence=0.78,
    delta_e=4.1,
    matched_profile_point=0.125,
    notes=["Mock veri — color_engine.pipeline.analyze() henüz bağlı değil (rapor §6.2)."],
)

_MOCK_RESCAN = ColorEngineResult(
    quality_score=0.31,
    rescan_recommended=True,
    notes=["Mock veri — düşük kalite senaryosu (parlama / bulanıklık)."],
)

_MOCK_FRESH = ColorEngineResult(
    quality_score=0.91,
    rescan_recommended=False,
    freshness_class="fresh",
    confidence=0.88,
    delta_e=2.3,
    matched_profile_point=0.03125,
    notes=["Mock veri — doğrulanmış eşik senaryosu (henüz gelmedi, önizleme)."],
)

_MOCK_TRANSITION = ColorEngineResult(
    quality_score=0.84,
    rescan_recommended=False,
    freshness_class="transition",
    confidence=0.71,
    delta_e=6.8,
    matched_profile_point=0.25,
    notes=["Mock veri — doğrulanmış eşik senaryosu (henüz gelmedi, önizleme)."],
)

_MOCK_SPOILED = ColorEngineResult(
    quality_score=0.90,
    rescan_recommended=False,
    freshness_class="spoiled",
    confidence=0.93,
    delta_e=11.4,
    matched_profile_point=1.0,
    notes=["Mock veri — doğrulanmış eşik senaryosu (henüz gelmedi, önizleme)."],
)

_FRESHNESS_LABELS = {"fresh": "TAZE", "transition": "GEÇİŞ", "spoiled": "BOZUK"}
_FRESHNESS_COLORS = {
    "fresh": T.C_FRESH,
    "transition": T.C_TRANSITION,
    "spoiled": T.C_SPOILED,
}


def user_body(page: ft.Page, nav) -> ft.Control:
    body = ft.Column(spacing=T.GAP_M)

    def show_scan() -> None:
        body.controls = [_scan_view(on_scan_default, _TEST_SCENARIOS)]
        page.update()

    async def _run_scan(result: ColorEngineResult) -> None:
        body.controls = [_loading_view()]
        page.update()
        await asyncio.sleep(1.0)  # kamera + color_engine gecikmesini simüle eder
        body.controls = [_result_view(page, result, on_rescan=show_scan)]
        page.update()

    def show_permission_denied() -> None:
        body.controls = [_permission_denied_view(show_scan)]
        page.update()

    async def on_scan_default(_e) -> None:
        await _run_scan(_MOCK_OK)

    async def on_test_fresh(_e) -> None:
        await _run_scan(_MOCK_FRESH)

    async def on_test_transition(_e) -> None:
        await _run_scan(_MOCK_TRANSITION)

    async def on_test_spoiled(_e) -> None:
        await _run_scan(_MOCK_SPOILED)

    async def on_test_low_quality(_e) -> None:
        await _run_scan(_MOCK_RESCAN)

    def on_test_no_permission(_e) -> None:
        show_permission_denied()

    _TEST_SCENARIOS = [
        ("Taze", on_test_fresh),
        ("Geçiş", on_test_transition),
        ("Bozuk", on_test_spoiled),
        ("Düşük kalite", on_test_low_quality),
        ("İzin yok", on_test_no_permission),
    ]

    body.controls = [_scan_view(on_scan_default, _TEST_SCENARIOS)]

    return screen(app_header("Tazelik", on_back=nav.login), body)


def _scan_view(on_scan, test_scenarios) -> ft.Control:
    viewfinder = ft.Container(
        height=220,
        border_radius=T.RADIUS,
        border=ft.Border.all(2, T.C_OUTLINE),
        bgcolor=T.C_ACCENT_BG,
        alignment=ft.Alignment(0, 0),
        content=ft.Column(
            expand=True,
            alignment=ft.MainAxisAlignment.CENTER,
            horizontal_alignment=ft.CrossAxisAlignment.CENTER,
            spacing=T.GAP_S,
            controls=[
                ft.Icon(ft.Icons.QR_CODE_SCANNER, size=48, color=T.C_PRIMARY),
                ft.Text("QR kodu çerçeveye alın", size=T.T_BODY, color=T.C_MUTED),
            ],
        ),
    )

    scan_button = ft.FilledButton(
        "Tazelik Tara",
        icon=ft.Icons.QR_CODE_SCANNER,
        height=52,
        on_click=on_scan,
    )

    test_buttons = ft.Row(
        wrap=True,
        spacing=T.GAP_XS,
        alignment=ft.MainAxisAlignment.CENTER,
        controls=[ft.TextButton(label, on_click=handler) for label, handler in test_scenarios],
    )

    return ft.Column(
        spacing=T.GAP_M,
        controls=[
            viewfinder,
            scan_button,
            section_card(
                "Test senaryoları (geliştirme)",
                ft.Text(
                    "Gerçek kamera/QR henüz bağlı değil — sonuç ekranlarını önizlemek için.",
                    size=T.T_CAPTION,
                    color=T.C_MUTED,
                ),
                test_buttons,
            ),
            section_card(
                "Son okumalar",
                ft.Text("Henüz okuma yok.", color=T.C_MUTED, size=T.T_BODY),
            ),
        ],
    )


def _loading_view() -> ft.Control:
    return ft.Column(
        spacing=T.GAP_M,
        horizontal_alignment=ft.CrossAxisAlignment.CENTER,
        controls=[
            ft.Container(height=T.GAP_L),
            ft.ProgressRing(),
            ft.Text("Taranıyor…", size=T.T_BODY, color=T.C_MUTED),
        ],
    )


def _permission_denied_view(on_retry) -> ft.Control:
    return ft.Column(
        spacing=T.GAP_M,
        controls=[
            section_card(
                "Kamera izni gerekli",
                ft.Row(
                    spacing=T.GAP_S,
                    vertical_alignment=ft.CrossAxisAlignment.START,
                    controls=[
                        ft.Icon(ft.Icons.NO_PHOTOGRAPHY_OUTLINED, color=T.C_MUTED),
                        ft.Text(
                            "Etiketi tarayabilmek için kamera izni gerekiyor. "
                            "Cihaz ayarlarından FreshQR için kamera iznini açın.",
                            size=T.T_BODY,
                            color=T.C_MUTED,
                            expand=True,
                        ),
                    ],
                ),
            ),
            ft.FilledButton(
                "Tekrar Dene",
                icon=ft.Icons.REFRESH,
                height=52,
                on_click=lambda e: on_retry(),
            ),
        ],
    )


def _result_view(page: ft.Page, result: ColorEngineResult, on_rescan) -> ft.Control:
    if result.rescan_recommended:
        return ft.Column(
            spacing=T.GAP_M,
            controls=[
                section_card(
                    "Okuma kalitesi yetersiz",
                    ft.Row(
                        spacing=T.GAP_S,
                        vertical_alignment=ft.CrossAxisAlignment.START,
                        controls=[
                            ft.Icon(ft.Icons.WARNING_AMBER_ROUNDED, color=T.C_TRANSITION),
                            ft.Text(
                                "Görüntü bulanık, parlamalı veya çok karanlık olabilir. "
                                "Yanlış sonuç göstermemek için tazelik sınıfı üretilmedi (§7.2).",
                                size=T.T_BODY,
                                color=T.C_MUTED,
                                expand=True,
                            ),
                        ],
                    ),
                    kv("Okuma kalitesi", f"{result.quality_score:.2f}"),
                ),
                ft.FilledButton(
                    "Yeniden Tara",
                    icon=ft.Icons.REFRESH,
                    height=52,
                    on_click=lambda e: on_rescan(),
                ),
            ],
        )

    if result.freshness_class:
        headline_text = _FRESHNESS_LABELS.get(result.freshness_class, result.freshness_class.upper())
        headline_color = _FRESHNESS_COLORS.get(result.freshness_class, T.C_PRIMARY)
    else:
        headline_text = result.technical_level or "Sonuç yok"
        headline_color = T.C_PRIMARY

    headline = ft.Text(
        headline_text,
        size=T.T_TITLE,
        weight=ft.FontWeight.BOLD,
        color=headline_color,
        text_align=ft.TextAlign.CENTER,
    )

    detail_rows: list[ft.Control] = [
        kv("Güven skoru", f"{result.confidence:.2f}" if result.confidence is not None else "—"),
        kv("ΔE", f"{result.delta_e:.2f}" if result.delta_e is not None else "—"),
        kv(
            "Eşleşen profil noktası",
            result.matched_profile_point if result.matched_profile_point is not None else "—",
        ),
        kv("Ölçülen modül", len(result.module_readings)),
    ]
    for note in result.notes:
        detail_rows.append(ft.Text(note, size=T.T_CAPTION, color=T.C_MUTED))

    details_container = ft.Container(
        visible=False,
        content=ft.Column(spacing=T.GAP_XS, controls=detail_rows),
    )

    def toggle_details(_e) -> None:
        details_container.visible = not details_container.visible
        details_button.text = (
            "Teknik detayları gizle" if details_container.visible else "Teknik detayları göster"
        )
        page.update()

    details_button = ft.TextButton("Teknik detayları göster", on_click=toggle_details)

    return ft.Column(
        spacing=T.GAP_M,
        controls=[
            section_card(
                "Tazelik sonucu",
                ft.Row([headline], alignment=ft.MainAxisAlignment.CENTER),
                kv("Ürün", _MOCK_LABEL_INFO["product_type"]),
                kv("Parti", _MOCK_LABEL_INFO["product_id"]),
                kv("Okuma kalitesi", "Uygun"),
            ),
            ft.Row([details_button], alignment=ft.MainAxisAlignment.CENTER),
            details_container,
            ft.FilledTonalButton(
                "Yeniden Tara",
                icon=ft.Icons.REFRESH,
                height=48,
                on_click=lambda e: on_rescan(),
            ),
        ],
    )
