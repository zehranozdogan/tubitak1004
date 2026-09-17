"""ECC seviyesi (Q vs H) ve QR boyutu deneysel karşılaştırması — rapor §5.2/4:
"Binary sınıf değişimi kaçınılmazsa bunu kontrollü 'intentional error' olarak
ele al; ECC Q/H ve QR boyutunu deneysel karşılaştır."

pytest tarafından TOPLANMAZ (dosya adı test_ ile başlamıyor); elle çalıştırılır:

    python3 tests/synthetic/benchmark_ecc_levels.py

Üç şeyi ölçer:
  1. Aynı payload için ECC seviyesi QR boyutunu (versiyonunu) nasıl etkiliyor.
  2. Her ECC seviyesinde, mevcut reaktif yoğunluklarımızda (DENSITY_FRACTION)
     gerçek bozulma (açı/bulanıklık/parlaklık) altında decode başarısı.
  3. Her ECC seviyesinde kaç kasıtlı-hata modülüne kadar güvenle tolere
     edildiği (benchmark_intentional_errors.py ile aynı yöntem).
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
from packages.qr_layout.reactive import select_intentional_errors  # noqa: E402
from packages.qr_layout.render import render_colored_image  # noqa: E402

PAYLOAD = {
    "product_id": "TR-ECC-BENCH",
    "product_type": "LEVREK",
    "production_date": "2026-09-17",
    "sensor_profile_id": "GENIPIN_PUTRESIN_v2",
    "layout_version": "QR_SENSOR_v4",
}
PAYLOAD_TEXT = json.dumps(PAYLOAD, ensure_ascii=False, separators=(",", ":"))

ECC_LEVELS = ["m", "q", "h"]  # rapor L'yi istemiyor (prototipte minimum ECC-M)
ANGLES = [0, 15, 30, 45]
BLURS = [0.0, 1.5, 3.0]
BRIGHTNESS_FACTORS = [0.5, 1.0, 1.6]
DENSITIES = ["low", "medium", "high"]

IERR_FRACTIONS = [0.05, 0.08, 0.10, 0.12, 0.15]
IERR_TRIALS = 5


def _decode_ok(image) -> bool:
    decoded = decode_qr_image(image)
    if not decoded:
        return False
    try:
        return json.loads(decoded) == PAYLOAD
    except ValueError:
        return False


def part1_qr_size() -> dict[str, int]:
    print("=== 1. Aynı payload, ECC seviyesine göre QR versiyonu/boyutu ===")
    versions = {}
    for ecc in ECC_LEVELS:
        qr = generate_qr(PAYLOAD_TEXT, error=ecc)
        n = qr.version * 4 + 17
        versions[ecc] = qr.version
        print(f"  ECC-{ecc.upper()}: versiyon {qr.version:2}  ({n}x{n} modül)")
    print()
    return versions


def part2_distortion() -> None:
    print("=== 2. ECC seviyesi x yoğunluk -> gerçek bozulma altında decode başarısı ===")
    print(f"{'ECC':5} {'yoğunluk':9}  başarı")
    print("-" * 32)
    for ecc in ECC_LEVELS:
        qr = generate_qr(PAYLOAD_TEXT, error=ecc)
        cands = reactive_candidates(qr)
        for density in DENSITIES:
            modules = select_reactive_modules(cands, density=density, seed=1)
            layout = build_layout(qr, modules, layout_version=PAYLOAD["layout_version"], density=density)
            ok = total = 0
            for state in ("fresh", "transition", "spoiled"):
                base = render_colored_image(qr, layout, state=state, scale=10, border=4)
                for angle, br, bf in itertools.product(ANGLES, BLURS, BRIGHTNESS_FACTORS):
                    image = viewing_angle(base, angle)
                    image = blur(image, br)
                    image = brightness(image, bf)
                    ok += _decode_ok(image)
                    total += 1
            print(f"ECC-{ecc.upper():4} {density:9}  {ok}/{total} (%{100*ok/total:.0f})")
    print()


def part3_intentional_error_tolerance() -> None:
    print("=== 3. ECC seviyesine göre kasıtlı-hata tolerans tavanı (%, aday havuzu) ===")
    print(f"{'ECC':5} {'oran':>6}  {'sayı':>5}  başarı")
    print("-" * 34)
    for ecc in ECC_LEVELS:
        qr = generate_qr(PAYLOAD_TEXT, error=ecc)
        cands = reactive_candidates(qr)
        sensor_modules = select_reactive_modules(cands, density="medium", seed=1)
        sensor_set = set(sensor_modules)
        pool_size = len(cands) - len(sensor_set)
        for frac in IERR_FRACTIONS:
            count = round(pool_size * frac)
            ok = 0
            for trial in range(IERR_TRIALS):
                errors = select_intentional_errors(
                    cands, count=count, exclude=sensor_set, min_spacing=1, seed=trial
                )
                layout = build_layout(
                    qr, sensor_modules, layout_version=PAYLOAD["layout_version"],
                    density="medium", intentional_errors=errors,
                )
                image = render_colored_image(qr, layout, state="spoiled", scale=10, border=4)
                ok += _decode_ok(image)
            print(f"ECC-{ecc.upper():4} %{100*frac:5.1f}  {count:5}  {ok}/{IERR_TRIALS}")
    print()


def main() -> None:
    versions = part1_qr_size()
    part2_distortion()
    part3_intentional_error_tolerance()

    print("=== YORUM ===")
    print(f"QR boyutu: M={versions['m']} < Q={versions['q']} < H={versions['h']} (aynı payload,")
    print("daha yüksek ECC = daha çok yedeklilik = daha büyük QR gerekiyor). Yukarıdaki")
    print("tablolar hangi seviyenin bu projenin yoğunluk/bozulma senaryolarında en iyi")
    print("dengeyi verdiğini gösterir — karar reactive.py'ye yazılı olarak kaydedilmeli.")


if __name__ == "__main__":
    main()
