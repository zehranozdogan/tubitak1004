"""Bozulma x decode başarı matrisi (rapor §11.2 / §11.3) — çalıştırılabilir rapor aracı.

pytest tarafından TOPLANMAZ (dosya adı test_ ile başlamıyor); elle çalıştırılır:

    python3 tests/synthetic/benchmark_distortion.py

Çıktısı §11.3 "Raporlanacak metrikler" tablosuna doğrudan girdi sağlar:
yoğunluk × durum × açı × bulanıklık × parlaklık kombinasyonlarında QR decode
başarı oranı.
"""

from __future__ import annotations

import itertools
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from packages.qr_layout import (  # noqa: E402
    build_layout,
    generate_qr,
    reactive_candidates,
    select_reactive_modules,
)
from packages.qr_layout.decode import decode_qr_image  # noqa: E402
from packages.qr_layout.distortion import blur, brightness, viewing_angle  # noqa: E402
from packages.qr_layout.render import render_colored_image  # noqa: E402

PAYLOAD = {
    "product_id": "TR-BENCH",
    "product_type": "LEVREK",
    "production_date": "2026-09-15",
    "sensor_profile_id": "GENIPIN_PUTRESIN_v2",
    "layout_version": "QR_SENSOR_v4",
}
PAYLOAD_TEXT = json.dumps(PAYLOAD, ensure_ascii=False, separators=(",", ":"))

ANGLES = [0, 15, 30, 45]        # rapor §11.2
BLURS = [0.0, 1.5, 3.0]         # yok / hafif / güçlü
BRIGHTNESS_FACTORS = [0.5, 1.0, 1.6]   # karanlık / normal / parlama
DENSITIES = ["low", "medium", "high"]
STATES = ["fresh", "transition", "spoiled"]


def _base_image(density: str, state: str):
    qr = generate_qr(PAYLOAD_TEXT, error="h")
    modules = select_reactive_modules(reactive_candidates(qr), density=density, seed=1)
    layout = build_layout(qr, modules, layout_version=PAYLOAD["layout_version"], density=density)
    return render_colored_image(qr, layout, state=state, scale=10, border=4)


def _decode_ok(image) -> bool:
    decoded = decode_qr_image(image)
    if not decoded:
        return False
    try:
        return json.loads(decoded) == PAYLOAD
    except ValueError:
        return False


def main() -> None:
    rows: list[tuple] = []
    for density, state in itertools.product(DENSITIES, STATES):
        base = _base_image(density, state)
        for angle, blur_r, bright_f in itertools.product(ANGLES, BLURS, BRIGHTNESS_FACTORS):
            image = viewing_angle(base, angle)
            image = blur(image, blur_r)
            image = brightness(image, bright_f)
            rows.append((density, state, angle, blur_r, bright_f, _decode_ok(image)))

    total = len(rows)
    success = sum(1 for r in rows if r[-1])

    print(f"{'yoğunluk':9} {'durum':11} {'açı':>4} {'blur':>5} {'parlk':>6}  sonuç")
    print("-" * 55)
    for density, state, angle, blur_r, bright_f, ok in rows:
        mark = "OK" if ok else "BAŞARISIZ"
        print(f"{density:9} {state:11} {angle:>3}° {blur_r:>5.1f} {bright_f:>6.1f}  {mark}")

    print("-" * 55)
    print(f"TOPLAM: {success}/{total} başarılı (%{100 * success / total:.0f})\n")

    print("--- Yoğunluğa göre başarı oranı ---")
    for density in DENSITIES:
        sub = [r for r in rows if r[0] == density]
        s = sum(1 for r in sub if r[-1])
        print(f"  {density:9} {s}/{len(sub)} (%{100 * s / len(sub):.0f})")

    print("\n--- Açıya göre başarı oranı ---")
    for angle in ANGLES:
        sub = [r for r in rows if r[2] == angle]
        s = sum(1 for r in sub if r[-1])
        print(f"  {angle:>3}°      {s}/{len(sub)} (%{100 * s / len(sub):.0f})")

    print("\n--- Bulanıklığa göre başarı oranı ---")
    for blur_r in BLURS:
        sub = [r for r in rows if r[3] == blur_r]
        s = sum(1 for r in sub if r[-1])
        print(f"  blur={blur_r:<4} {s}/{len(sub)} (%{100 * s / len(sub):.0f})")

    print("\n--- Parlaklığa göre başarı oranı ---")
    for bright_f in BRIGHTNESS_FACTORS:
        sub = [r for r in rows if r[4] == bright_f]
        s = sum(1 for r in sub if r[-1])
        print(f"  x{bright_f:<4}    {s}/{len(sub)} (%{100 * s / len(sub):.0f})")


if __name__ == "__main__":
    main()
