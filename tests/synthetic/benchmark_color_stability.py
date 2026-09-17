"""Yoğunluk x renk ölçüm kararlılığı — rapor §5.2 "İlk prototipte istenecek
üç layout" kutusu: "Karar yalnız görsel beğeniyle değil; QR decode başarısı +
RENK ÖLÇÜM KARARLILIĞI + baskı uygulanabilirliği birlikte değerlendirilerek
verilmeli."

decode başarısı zaten tests/synthetic/benchmark_distortion.py'de ölçülüyor.
Bu script AYRI bir soruyu ölçer (rapor §11 girişindeki ilkeyle aynı: "QR ve
renk ölçümünün güvenilirliği ayrı ayrı kanıtlanmalı"): QR başarıyla
okunduğunda, ARDINDAN yapılan renk ölçümü (color_engine.pipeline.analyze)
ne kadar KARARLI/DOĞRU kalıyor — yoğunluk arttıkça daha mı kötüleşiyor?

pytest tarafından TOPLANMAZ; elle çalıştırılır:

    python3 tests/synthetic/benchmark_color_stability.py
"""

from __future__ import annotations

import itertools
import json
import statistics
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

import numpy as np  # noqa: E402

from packages.color_engine import analyze  # noqa: E402
from packages.qr_layout import (  # noqa: E402
    build_layout,
    generate_qr,
    reactive_candidates,
    select_reactive_modules,
)
from packages.qr_layout.distortion import blur, brightness, viewing_angle  # noqa: E402
from packages.qr_layout.render import render_colored_image  # noqa: E402

PAYLOAD = {
    "product_id": "TR-STABILITY-BENCH",
    "product_type": "LEVREK",
    "production_date": "2026-09-17",
    "sensor_profile_id": "DEMO_QR_STATE_COLORS_v1",
    "layout_version": "QR_SENSOR_v4",
}
PAYLOAD_TEXT = json.dumps(PAYLOAD, ensure_ascii=False, separators=(",", ":"))
PROFILE = json.loads(
    (Path(__file__).resolve().parents[2] / "packages/profile_schema/examples"
     / "DEMO_QR_STATE_COLORS_v1.sensor_profile.json").read_text(encoding="utf-8")
)

DENSITIES = ["low", "medium", "high"]

# YALNIZCA decode'un GÜVENİLİR şekilde başardığı hafif/orta koşullar (rapor
# §11 girişi: "QR ve renk ölçümünün güvenilirliği ayrı ayrı kanıtlanmalı" —
# burada decode başarısını değil, decode BAŞARILI OLDUĞUNDA renk ölçümünün
# ne kadar tutarlı kaldığını izole ediyoruz).
ANGLES = [0, 15, 30]
BLURS = [0.0, 0.8, 1.5]
BRIGHTNESS_FACTORS = [0.75, 1.0, 1.3]


def _to_bgr_array(image) -> np.ndarray:
    return np.array(image.convert("RGB"))[:, :, ::-1]


def main() -> None:
    qr = generate_qr(PAYLOAD_TEXT, error="h")
    cands = reactive_candidates(qr)

    print(f"{'yoğunluk':9} {'hücre':>5}  {'doğru':>6} {'ret/None':>9} {'yanlış':>7}   ΔE (ort±sd, doğrularda)")
    print("-" * 72)

    for density in DENSITIES:
        modules = select_reactive_modules(cands, density=density, seed=1)
        layout = build_layout(qr, modules, layout_version=PAYLOAD["layout_version"], density=density)
        base = render_colored_image(qr, layout, state="fresh", scale=10, border=4)

        correct = wrong = none_class = 0
        delta_es: list[float] = []

        for angle, br, bf in itertools.product(ANGLES, BLURS, BRIGHTNESS_FACTORS):
            image = viewing_angle(base, angle)
            image = blur(image, br)
            image = brightness(image, bf)
            bgr = _to_bgr_array(image)

            result = analyze(bgr, PROFILE, layout)

            if result.rescan_recommended or result.freshness_class is None:
                none_class += 1
            elif result.freshness_class == "fresh":
                correct += 1
                if result.delta_e is not None:
                    delta_es.append(result.delta_e)
            else:
                wrong += 1

        total = correct + wrong + none_class
        de_txt = f"{statistics.mean(delta_es):.2f}±{statistics.pstdev(delta_es):.2f}" if delta_es else "—"
        print(f"{density:9} {len(modules):5}  {correct:3}/{total:<3} {none_class:6}/{total:<3} {wrong:4}/{total:<3}   {de_txt}")

    print("\nYORUM: 'doğru' = freshness_class doğru şekilde 'fresh' çıktı. 'ret/None' =")
    print("kalite/eşleşme yetersiz görüldüğü için sınıf üretilmedi (güvenli taraf, §7.2).")
    print("'yanlış' = YANLIŞ sınıf üretildi (en kötü senaryo). ΔE, doğru çıkan")
    print("okumalar arasında ne kadar dağıldığını gösterir — düşük sd daha kararlı demek.")


if __name__ == "__main__":
    main()
