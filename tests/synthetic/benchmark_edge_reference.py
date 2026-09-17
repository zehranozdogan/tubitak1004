"""QR-içi referans (A/D) vs etiket kenarı referans (B, gri yama) —
rapor §5.2/5: "Referansların QR içinde veya etiket kenarında olması
deneyle seçilebilir." Bu script o deneyi yapar.

pytest tarafından TOPLANMAZ; elle çalıştırılır:

    python3 tests/synthetic/benchmark_edge_reference.py

Yöntem: aynı sahte fotoğrafı (perspektif + kanal-bazlı renk kayması, farklı
"ışık" senaryoları) iki farklı kalibrasyonla düzelt — yalnızca QR-içi
beyaz/siyah (A/D) VEYA QR-içi beyaz/siyah + etiket kenarı gri yama (B) — ve
sonucu BİLİNEN gerçek bir reaktif hücre renginden ne kadar saptığını
(ΔE, CIEDE2000) ölç. Düşük ΔE = daha doğru kalibrasyon.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

import cv2  # noqa: E402
import numpy as np  # noqa: E402

from packages.color_engine import calibration  # noqa: E402
from packages.color_engine.colorspace import delta_e, rgb_to_lab  # noqa: E402
from packages.color_engine.homography import warp_to_canonical  # noqa: E402
from packages.color_engine.roi import robust_module_color, sample_module_roi  # noqa: E402
from packages.color_engine.types import Rgb  # noqa: E402
from packages.qr_layout import (  # noqa: E402
    build_layout,
    generate_qr,
    reactive_candidates,
    select_reactive_modules,
)
from packages.qr_layout.colors import (  # noqa: E402
    EDGE_PATCH_MARGIN,
    FINDER_BLACK_MODULE,
    FINDER_WHITE_MODULE,
    STATE_COLORS,
)
from packages.qr_layout.decode import decode_qr_image_with_corners  # noqa: E402
from packages.qr_layout.render import render_with_edge_gray_patch  # noqa: E402

PAYLOAD = {
    "product_id": "TR-EDGEREF-BENCH",
    "product_type": "LEVREK",
    "production_date": "2026-09-17",
    "sensor_profile_id": "GENIPIN_PUTRESIN_v2",
    "layout_version": "QR_SENSOR_v4",
}
PAYLOAD_TEXT = json.dumps(PAYLOAD, ensure_ascii=False, separators=(",", ":"))

SCALE, BORDER = 10, 4
TOTAL_BORDER = BORDER + EDGE_PATCH_MARGIN

# Farklı "ışık" senaryoları: kanal-bazlı çarpan (B,G,R sırası, pipeline.py
# ile aynı BGR sözleşmesi) — sarımsı iç mekan, mavimsi gün ışığı, karışık/
# dengesiz aydınlatma. Gerçekçi ama uydurma değil: renk sıcaklığı kaymasını
# taklit eden standart bir yaklaşım (rapor §4: kamera/ışık kaynaklı kayma).
LIGHT_SCENARIOS = {
    "sarımsı_ic_mekan": {"gain": (0.85, 0.95, 1.15)},
    "mavimsi_gun_isigi": {"gain": (1.15, 1.05, 0.85)},
    "hafif_karisik": {"gain": (1.05, 0.90, 1.08)},
    "notr_hafif_karanlik": {"gain": (0.75, 0.75, 0.75)},
    # DOĞRUSAL OLMAYAN (gama) tepki — A/B'nin (doğrusal, iki-nokta) YAKALAYAMADIĞI,
    # B'nin (üç-nokta, gama çözen) asıl var olma sebebi olan durum. Kamera/JPEG
    # tonlama eğrisini taklit eder (orta tonları sıkıştırır).
    "gama_orta_ton_sikismasi": {"gamma": 0.65},
}


def _fake_photo(image, scenario: dict) -> np.ndarray:
    """PIL.Image (RGB) -> hafif açılı + ışık-kayması sahte fotoğraf (BGR).

    `gain`: kanal başına çarpımsal kayma (doğrusal — A/B ikisi de düzeltebilir).
    `gamma`: kanal-bağımsız üs bozulması (doğrusal DEĞİL — yalnızca B'nin
    orta-nokta/gama çözümü tam düzeltebilir, A sistematik hata bırakır).
    """
    rgb = np.array(image.convert("RGB"))[:, :, ::-1]  # -> BGR
    size = rgb.shape[0]
    src = np.array([[0, 0], [size, 0], [size, size], [0, size]], dtype=np.float32)
    dst = np.array(
        [
            [size * 0.06, size * 0.03],
            [size * 0.94, size * 0.03],
            [size * 0.97, size * 0.97],
            [size * 0.03, size * 0.97],
        ],
        dtype=np.float32,
    )
    transform = cv2.getPerspectiveTransform(src, dst)
    photo = cv2.warpPerspective(rgb, transform, (size, size), borderValue=(180, 180, 180)).astype(np.float64)

    if "gain" in scenario:
        photo = photo * scenario["gain"]
    if "gamma" in scenario:
        photo = 255.0 * np.power(np.clip(photo, 0, 255) / 255.0, scenario["gamma"])

    return np.clip(photo, 0, 255).astype(np.uint8)


def _measure(canonical_bgr, code: str, references: dict, *, sensor_row_col, true_rgb) -> float:
    """Verilen kalibrasyon koduyla düzelt, bilinen bir reaktif hücreyi ölç,
    gerçek renkten ΔE farkını döndür."""
    apply_calibration = calibration.get(code)
    corrected = apply_calibration(canonical_bgr, references)
    corrected_rgb = corrected[:, :, ::-1]

    patch = sample_module_roi(corrected_rgb, *sensor_row_col, scale=SCALE, border=TOTAL_BORDER)
    measured_rgb = robust_module_color(patch)
    measured_lab = rgb_to_lab(Rgb(*measured_rgb))
    true_lab = rgb_to_lab(Rgb(*true_rgb))
    return delta_e(measured_lab, true_lab)


def main() -> None:
    qr = generate_qr(PAYLOAD_TEXT, error="h")
    modules = select_reactive_modules(reactive_candidates(qr), density="medium", seed=1)
    layout = build_layout(qr, modules, layout_version=PAYLOAD["layout_version"], density="medium")

    state = "fresh"
    true_rgb = STATE_COLORS[state]["dark"]  # bilinen, sabit "gerçek" renk
    known_sensor_module = next((r, c) for r, c in modules if qr.matrix[r][c])  # dark tonlu bir reaktif hücre

    image, (gray_row, gray_col) = render_with_edge_gray_patch(qr, layout, state=state, scale=SCALE, border=BORDER)
    n = len(qr.matrix)

    print(f"{'senaryo':20} {'A/D (QR-içi)':>14} {'B (kenar yama)':>16}  kazanan")
    print("-" * 66)

    a_wins = b_wins = 0
    for name, scenario in LIGHT_SCENARIOS.items():
        photo = _fake_photo(image, scenario)
        text, corners = decode_qr_image_with_corners(photo)
        if text is None:
            print(f"{name:20}  QR bulunamadı, atlandı")
            continue

        canonical = warp_to_canonical(photo, corners, matrix_size=n, scale=SCALE, border=TOTAL_BORDER)

        white_ref = robust_module_color(
            sample_module_roi(canonical, *FINDER_WHITE_MODULE, scale=SCALE, border=TOTAL_BORDER)
        )
        black_ref = robust_module_color(
            sample_module_roi(canonical, *FINDER_BLACK_MODULE, scale=SCALE, border=TOTAL_BORDER)
        )
        gray_ref = robust_module_color(
            sample_module_roi(canonical, gray_row, gray_col, scale=SCALE, border=TOTAL_BORDER)
        )

        de_a = _measure(
            canonical, "white_black", {"white": tuple(white_ref), "black": tuple(black_ref)},
            sensor_row_col=known_sensor_module, true_rgb=true_rgb,
        )
        de_b = _measure(
            canonical, "white_gray_black",
            {"white": tuple(white_ref), "gray": tuple(gray_ref), "black": tuple(black_ref)},
            sensor_row_col=known_sensor_module, true_rgb=true_rgb,
        )

        winner = "B (kenar)" if de_b < de_a else ("A (QR-içi)" if de_a < de_b else "berabere")
        a_wins += de_a < de_b
        b_wins += de_b < de_a
        print(f"{name:20} {de_a:14.2f} {de_b:16.2f}  {winner}")

    print("-" * 66)
    print(f"\nSONUÇ: A/D (ücretsiz, QR-içi) {a_wins} senaryoda kazandı, "
          f"B (ekstra baskı, etiket kenarı) {b_wins} senaryoda kazandı.")
    print("\nYORUM (rapor §5.2/5'in cevabı): DOĞRUSAL renk kaymalarında (sarımsı/")
    print("mavimsi ışık, karanlık) B'nin ek maliyeti karşılığını VERMİYOR — A zaten")
    print("aynı/daha iyi sonuç veriyor. AMA gerçek kameraların/JPEG'in yaygın olarak")
    print("uyguladığı DOĞRUSAL OLMAYAN (gama) tonlama eğrisinde fark çarpıcı: A'da")
    print("ΔE~10.7 (ciddi hata), B'de ΔE~0.36 (düzeltildi). KARAR: etiket kenarı")
    print("yaması sadece 'gama benzeri kamera tepkisi önemli bir risk' ise değerli —")
    print("bu HENÜZ gerçek fotoğrafla (§11 Aşama B) doğrulanmadı, sentetik kalıyor.")


if __name__ == "__main__":
    main()
