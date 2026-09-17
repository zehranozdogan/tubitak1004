"""A (QR-içi) vs B (1 gri kenar yaması) vs C (4 farklı renk kenar yaması) —
rapor §6.1 A/B/C karşılaştırması. Devamı: tests/synthetic/benchmark_edge_
reference.py (orada sadece A vs B vardı).

pytest tarafından TOPLANMAZ; elle çalıştırılır:

    python3 tests/synthetic/benchmark_multicolor_reference.py

Üç bozulma senaryosu:
  1. Doğrusal kanal kazancı (ışık rengi) — A/B/C'nin hepsi düzeltebilmeli.
  2. Gama (tonlama eğrisi) — yalnızca B ve C düzeltebilmeli (A değil).
  3. KANALLAR ARASI KARIŞIM (sensör crosstalk) — yalnızca C düzeltebilmeli;
     A ve B sadece kanal-başına (diyagonal) düzeltme yapar, karışımı (diyagonal
     OLMAYAN) modelleyemez. Bu, C'nin var olma sebebidir.
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
    EDGE_REFERENCE_COLORS,
    FINDER_BLACK_MODULE,
    FINDER_WHITE_MODULE,
    STATE_COLORS,
    edge_patch_positions,
)
from packages.qr_layout.decode import decode_qr_image_with_corners  # noqa: E402
from packages.qr_layout.generator import module_matrix  # noqa: E402
from packages.qr_layout.render import render_with_edge_reference_patches  # noqa: E402

PAYLOAD = {
    "product_id": "TR-MULTICOLOR-BENCH",
    "product_type": "LEVREK",
    "production_date": "2026-09-17",
    "sensor_profile_id": "GENIPIN_PUTRESIN_v2",
    "layout_version": "QR_SENSOR_v4",
}
PAYLOAD_TEXT = json.dumps(PAYLOAD, ensure_ascii=False, separators=(",", ":"))

SCALE, BORDER = 14, 4
TOTAL_BORDER = BORDER + EDGE_PATCH_MARGIN

# Kanallar arası karışım matrisi (BGR sırası, pipeline sözleşmesiyle aynı) —
# gerçek bir kamera sensöründeki renk filtresi sızıntısını taklit eder.
CROSSTALK_MATRIX = np.array([
    [0.80, 0.12, 0.06],
    [0.10, 0.78, 0.14],
    [0.05, 0.15, 0.82],
])

SCENARIOS = {
    "dogrusal_isik_kaymasi": {"gain": (0.85, 0.95, 1.15)},
    "gama_orta_ton": {"gamma": 0.65},
    "kanal_karismasi": {"crosstalk": CROSSTALK_MATRIX},
}


def _fake_photo(image, scenario: dict) -> np.ndarray:
    rgb = np.array(image.convert("RGB"))[:, :, ::-1]  # -> BGR
    size = rgb.shape[0]
    src = np.array([[0, 0], [size, 0], [size, size], [0, size]], dtype=np.float32)
    dst = np.array(
        [[size * 0.06, size * 0.03], [size * 0.94, size * 0.03],
         [size * 0.97, size * 0.97], [size * 0.03, size * 0.97]],
        dtype=np.float32,
    )
    transform = cv2.getPerspectiveTransform(src, dst)
    photo = cv2.warpPerspective(rgb, transform, (size, size), borderValue=(180, 180, 180)).astype(np.float64)

    if "gain" in scenario:
        photo = photo * scenario["gain"]
    if "gamma" in scenario:
        photo = 255.0 * np.power(np.clip(photo, 0, 255) / 255.0, scenario["gamma"])
    if "crosstalk" in scenario:
        flat = photo.reshape(-1, 3)
        photo = (flat @ scenario["crosstalk"].T).reshape(photo.shape)

    return np.clip(photo, 0, 255).astype(np.uint8)


def _measure(canonical_bgr, code, refs, sensor_rc, true_rgb) -> float:
    corrected = calibration.get(code)(canonical_bgr, refs)[:, :, ::-1]
    patch = sample_module_roi(corrected, *sensor_rc, scale=SCALE, border=TOTAL_BORDER)
    measured = robust_module_color(patch)
    return delta_e(rgb_to_lab(Rgb(*measured)), rgb_to_lab(Rgb(*true_rgb)))


def main() -> None:
    qr = generate_qr(PAYLOAD_TEXT, error="h")
    matrix = module_matrix(qr)
    modules = select_reactive_modules(reactive_candidates(qr), density="medium", seed=1)
    layout = build_layout(qr, modules, layout_version=PAYLOAD["layout_version"], density="medium")
    n = len(matrix)

    state = "fresh"
    true_rgb = STATE_COLORS[state]["dark"]
    known_rc = next((r, c) for r, c in modules if matrix[r][c] == 1)

    image, patch_positions = render_with_edge_reference_patches(qr, layout, state=state, scale=SCALE, border=BORDER)

    print(f"{'senaryo':22} {'A (QR-içi)':>11} {'B (1 gri)':>11} {'C (4 renk)':>11}  kazanan")
    print("-" * 72)

    wins = {"A": 0, "B": 0, "C": 0}
    for name, scenario in SCENARIOS.items():
        photo = _fake_photo(image, scenario)
        text, corners = decode_qr_image_with_corners(photo)
        if text is None:
            print(f"{name:22}  QR bulunamadı")
            continue

        canonical = warp_to_canonical(photo, corners, matrix_size=n, scale=SCALE, border=TOTAL_BORDER)
        white_ref = robust_module_color(sample_module_roi(canonical, *FINDER_WHITE_MODULE, scale=SCALE, border=TOTAL_BORDER))
        black_ref = robust_module_color(sample_module_roi(canonical, *FINDER_BLACK_MODULE, scale=SCALE, border=TOTAL_BORDER))
        patch_measurements = {
            pname: robust_module_color(sample_module_roi(canonical, prow, pcol, scale=SCALE, border=TOTAL_BORDER))
            for pname, (prow, pcol) in patch_positions.items()
        }

        de_a = _measure(canonical, "white_black", {"white": tuple(white_ref), "black": tuple(black_ref)}, known_rc, true_rgb)
        de_b = _measure(
            canonical, "white_gray_black",
            {"white": tuple(white_ref), "gray": tuple(patch_measurements["gray"]), "black": tuple(black_ref)},
            known_rc, true_rgb,
        )
        # ÖNEMLİ: `canonical` BGR sıradadır (bu dosyadaki her şey gibi); "true"
        # noktalar da AYNI (BGR) sırada verilmeli — yoksa fit BGR->RGB öğrenir,
        # ama _measure() çıktıyı YİNE BGR->RGB diye çevirdiği için (aslında
        # zaten RGB olan bir şeyi tekrar ters çevirir) kanallar karışır. Elle
        # bulundu (bkz. tests/device/results_2026-09-17c.md).
        def _to_bgr(rgb: tuple[int, int, int]) -> tuple[int, int, int]:
            return (rgb[2], rgb[1], rgb[0])

        captured = [tuple(white_ref), tuple(black_ref)] + [tuple(v) for v in patch_measurements.values()]
        true_points = [_to_bgr((255, 255, 255)), _to_bgr((0, 0, 0))] + [
            _to_bgr(EDGE_REFERENCE_COLORS[k]) for k in patch_measurements
        ]
        de_c = _measure(
            canonical, "multicolor_patch", {"captured": captured, "true": true_points}, known_rc, true_rgb,
        )

        scores = {"A": de_a, "B": de_b, "C": de_c}
        winner = min(scores, key=scores.get)
        wins[winner] += 1
        print(f"{name:22} {de_a:11.2f} {de_b:11.2f} {de_c:11.2f}  {winner}")

    print("-" * 72)
    print(f"\nKazanma sayısı: A={wins['A']}  B={wins['B']}  C={wins['C']}")
    print("\nBEKLENTİ: 'kanal_karismasi' senaryosunda C açıkça kazanmalı (A/B'nin")
    print("modelleyemediği diyagonal-olmayan bir bozulma); diğer ikisinde C'nin")
    print("B'ye göre belirgin bir avantajı olmayabilir (fazladan renk noktası o")
    print("bozulma türleri için gereksiz karmaşıklık).")


if __name__ == "__main__":
    main()
