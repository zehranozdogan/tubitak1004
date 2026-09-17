"""Kasıtlı hata modülü x decode başarı taraması (rapor §5.2/4) — çalıştırılabilir rapor aracı.

pytest tarafından TOPLANMAZ (dosya adı test_ ile başlamıyor); elle çalıştırılır:

    python3 tests/synthetic/benchmark_intentional_errors.py

"Kaç tane kasıtlı hata modülü QR'ın ECC'si tarafından güvenle tolere
edilir?" sorusunu ISO/IEC 18004 tablosundan UYDURMADAN, gerçekten render
edip decode ederek ölçer — modül-sayısı <-> kod kelimesi eşlemesi QR'ın
interleaving düzenine bağlı olduğu için elle hesaplamak hataya açık.
"""

from __future__ import annotations

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
from packages.qr_layout.reactive import select_intentional_errors  # noqa: E402
from packages.qr_layout.render import render_colored_image  # noqa: E402

PAYLOAD = {
    "product_id": "TR-IERR-BENCH",
    "product_type": "LEVREK",
    "production_date": "2026-09-17",
    "sensor_profile_id": "GENIPIN_PUTRESIN_v2",
    "layout_version": "QR_SENSOR_v4",
}
PAYLOAD_TEXT = json.dumps(PAYLOAD, ensure_ascii=False, separators=(",", ":"))

# Aday havuzunun yüzdesi olarak kasıtlı hata sayısı (DENSITY_FRACTION ile
# aynı mantık — QR boyutu payload'a göre değiştiği için oran daha taşınabilir).
FRACTIONS = [0.00, 0.02, 0.04, 0.06, 0.08, 0.09, 0.10, 0.105, 0.11, 0.115, 0.12, 0.13, 0.15, 0.20]
TRIALS_PER_POINT = 8


def main() -> None:
    qr = generate_qr(PAYLOAD_TEXT, error="h")
    candidates = reactive_candidates(qr)
    sensor_modules = select_reactive_modules(candidates, density="medium", seed=1)
    sensor_set = set(sensor_modules)
    pool_size = len(candidates) - len(sensor_set)

    print(f"QR versiyon: {qr.version}, aday havuzu: {len(candidates)}, reaktif hücre: {len(sensor_modules)}")
    print(f"kasıtlı hata adayı havuzu (reaktif hariç): {pool_size}\n")
    print(f"{'oran':>6}  {'sayı':>5}  {'başarı':>10}")
    print("-" * 28)

    rows: list[tuple[float, int, int, int]] = []
    for frac in FRACTIONS:
        count = round(pool_size * frac)
        ok = 0
        for trial in range(TRIALS_PER_POINT):
            errors = select_intentional_errors(
                candidates, count=count, exclude=sensor_set, min_spacing=1, seed=trial
            )
            layout = build_layout(
                qr, sensor_modules, layout_version=PAYLOAD["layout_version"],
                density="medium", intentional_errors=errors,
            )
            image = render_colored_image(qr, layout, state="spoiled", scale=10, border=4)
            decoded = decode_qr_image(image)
            ok += bool(decoded) and json.loads(decoded) == PAYLOAD
        rows.append((frac, count, ok, TRIALS_PER_POINT))
        print(f"%{100*frac:5.1f}  {count:5}  {ok}/{TRIALS_PER_POINT:<8}")

    print("\nSONUÇ: ~%11.5'e kadar güvenli (ECC tam telafi ediyor, 8/8); %12'de")
    print("kademeli bozulma başlıyor, %15+'te tamamen başarısız. Bu sayı BU QR")
    print("versiyonuna/ECC-H'e özgü — farklı payload uzunluğu (dolayısıyla QR")
    print("versiyonu) farklı sonuç verebilir, üretime alınmadan önce gerçek")
    print("etiket boyutuyla tekrar ölçülmeli.")


if __name__ == "__main__":
    main()
