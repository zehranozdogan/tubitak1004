"""Gerçek cihaz/fotoğraf testlerini çalıştırıp rapor §11.3 metrik CSV'sini üretir.

Kullanım:
    python tests/device/run_test.py tests/device/manifest.csv

`manifest.csv` sütunları (elle doldurulur — bu README.md'deki ölçüm logu
şemasının GİRDİ tarafı):
    photo_path, phone_model, camera, lighting, color_temp_k, distance_cm,
    angle_deg, flash, expected_state, note

`expected_state` boş bırakılabilir (ground-truth yoksa tazelik doğruluğu
hesaplanmaz, §11.3 — "yalnızca doğrulanmış ground-truth varsa").

Çıktı: `tests/device/raw/results_<timestamp>.csv` (README'deki ölçüm logu
şemasıyla birebir) + konsola özet metrikler.
"""

from __future__ import annotations

import csv
import json
import sys
import time
from datetime import datetime
from pathlib import Path

import numpy as np
from PIL import Image

_REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_REPO_ROOT))

from packages.color_engine.pipeline import analyze  # noqa: E402
from packages.profile_schema.loader import (  # noqa: E402
    EXAMPLES_DIR,
    load_layout_version,
    load_sensor_profile,
)
from packages.qr_layout.decode import decode_qr_image_with_corners  # noqa: E402

_OUT_DIR = _REPO_ROOT / "out"
_LOG_FIELDS = [
    "timestamp", "phone_model", "camera", "lighting", "color_temp_k", "distance_cm",
    "angle_deg", "flash", "layout_version", "sensor_profile_id", "decode_ok",
    "decode_attempts", "decode_ms", "delta_e", "quality_score", "rescan",
    "technical_level", "freshness_class", "matched_profile_point", "expected_state",
    "correct", "total_ms", "note",
]


def _decode_with_attempts(image) -> tuple[str | None, object, int]:
    """decode_qr_image_with_corners'ı sarmalar; kaç dedektör denemesi
    gerektiğini de döner (README log şemasındaki decode_attempts)."""
    import cv2

    array = np.array(image.convert("RGB"))[:, :, ::-1] if hasattr(image, "convert") else image
    for attempt, detector in enumerate((cv2.QRCodeDetectorAruco(), cv2.QRCodeDetector()), start=1):
        text, points = detector.detectAndDecode(array)[:2]
        if text and points is not None and len(points) > 0:
            return (text, points.reshape(4, 2), attempt)
    return (None, None, 2)


def _find_layout_version(product_id: str, layout_version_id: str) -> dict | None:
    stem = f"{product_id}_{layout_version_id}"
    path = _OUT_DIR / f"{stem}.layout_version.json"
    if path.exists():
        return load_layout_version(path)
    return None


def run_one(row: dict) -> dict:
    result_row = {field: "" for field in _LOG_FIELDS}
    result_row.update(
        timestamp=datetime.now().isoformat(timespec="seconds"),
        phone_model=row.get("phone_model", ""),
        camera=row.get("camera", ""),
        lighting=row.get("lighting", ""),
        color_temp_k=row.get("color_temp_k", ""),
        distance_cm=row.get("distance_cm", ""),
        angle_deg=row.get("angle_deg", ""),
        flash=row.get("flash", ""),
        expected_state=row.get("expected_state", ""),
        note=row.get("note", ""),
    )

    photo_path = Path(row["photo_path"])
    if not photo_path.is_absolute():
        photo_path = _REPO_ROOT / photo_path
    try:
        pil_image = Image.open(photo_path)
    except OSError as ex:
        result_row["decode_ok"] = False
        result_row["note"] = f"{result_row['note']} | dosya açılamadı: {ex}".strip(" |")
        return result_row

    t0 = time.perf_counter()
    text, corners, attempts = _decode_with_attempts(pil_image)
    decode_ms = (time.perf_counter() - t0) * 1000
    result_row["decode_ms"] = round(decode_ms, 1)
    result_row["decode_attempts"] = attempts
    result_row["decode_ok"] = bool(text)

    if not text:
        return result_row

    try:
        payload = json.loads(text)
    except ValueError:
        result_row["note"] = f"{result_row['note']} | payload JSON degil".strip(" |")
        return result_row

    result_row["layout_version"] = payload.get("layout_version", "")
    result_row["sensor_profile_id"] = payload.get("sensor_profile_id", "")

    layout_version = _find_layout_version(payload.get("product_id", ""), payload.get("layout_version", ""))
    if layout_version is None:
        result_row["note"] = f"{result_row['note']} | out/ icinde layout_version bulunamadi".strip(" |")
        return result_row

    try:
        sensor_profile = load_sensor_profile(EXAMPLES_DIR / f"{payload['sensor_profile_id']}.sensor_profile.json")
    except OSError:
        result_row["note"] = f"{result_row['note']} | sensor_profile bulunamadi".strip(" |")
        return result_row

    array = np.array(pil_image.convert("RGB"))[:, :, ::-1]
    analysis = analyze(array, sensor_profile, layout_version, qr_corners=corners)
    total_ms = (time.perf_counter() - t0) * 1000

    result_row["delta_e"] = round(analysis.delta_e, 3) if analysis.delta_e is not None else ""
    result_row["quality_score"] = round(analysis.quality_score, 3)
    result_row["rescan"] = analysis.rescan_recommended
    result_row["technical_level"] = analysis.technical_level or ""
    result_row["freshness_class"] = analysis.freshness_class or ""
    result_row["matched_profile_point"] = (
        analysis.matched_profile_point if analysis.matched_profile_point is not None else ""
    )
    result_row["total_ms"] = round(total_ms, 1)

    expected = row.get("expected_state") or ""
    if expected:
        result_row["correct"] = analysis.freshness_class == expected
    return result_row


_SUMMARY_FIELDS = [
    "run_timestamp", "manifest", "n", "decode_success_rate", "mean_delta_e",
    "min_delta_e", "max_delta_e", "rescan_rate", "accuracy", "mean_total_ms",
]


def _compute_summary(rows: list[dict], *, manifest_name: str) -> dict:
    total = len(rows)
    decoded = [r for r in rows if r["decode_ok"] in (True, "True")]
    delta_es = [float(r["delta_e"]) for r in decoded if r["delta_e"] != ""]
    rescans = [r for r in decoded if r["rescan"] in (True, "True")]
    with_ground_truth = [r for r in decoded if r["expected_state"]]
    correct = [r for r in with_ground_truth if r["correct"] in (True, "True")]
    total_mss = [float(r["total_ms"]) for r in decoded if r["total_ms"] != ""]

    return {
        "run_timestamp": datetime.now().isoformat(timespec="seconds"),
        "manifest": manifest_name,
        "n": total,
        "decode_success_rate": round(len(decoded) / total, 3) if total else "",
        "mean_delta_e": round(sum(delta_es) / len(delta_es), 3) if delta_es else "",
        "min_delta_e": round(min(delta_es), 3) if delta_es else "",
        "max_delta_e": round(max(delta_es), 3) if delta_es else "",
        "rescan_rate": round(len(rescans) / len(decoded), 3) if decoded else "",
        "accuracy": round(len(correct) / len(with_ground_truth), 3) if with_ground_truth else "",
        "mean_total_ms": round(sum(total_mss) / len(total_mss), 1) if total_mss else "",
    }


def _print_summary(summary: dict) -> None:
    print(f"\n=== Ozet ({summary['n']} okuma) ===")
    print(f"QR decode basarisi : {summary['decode_success_rate']}")
    if summary["mean_delta_e"] != "":
        print(f"Ortalama dE        : {summary['mean_delta_e']} (min {summary['min_delta_e']}, max {summary['max_delta_e']})")
    print(f"Yeniden tara orani : {summary['rescan_rate']}")
    if summary["accuracy"] != "":
        print(f"Tazelik dogrulugu  : {summary['accuracy']}")
    if summary["mean_total_ms"] != "":
        print(f"Ortalama sure      : {summary['mean_total_ms']} ms")


def main() -> None:
    if len(sys.argv) != 2:
        print("Kullanim: python tests/device/run_test.py <manifest.csv>")
        raise SystemExit(1)

    manifest_path = Path(sys.argv[1])
    with open(manifest_path, "r", encoding="utf-8") as fh:
        rows = list(csv.DictReader(fh))

    results = [run_one(row) for row in rows]

    device_dir = Path(__file__).resolve().parent
    raw_dir = device_dir / "raw"
    raw_dir.mkdir(exist_ok=True)
    raw_path = raw_dir / f"results_{datetime.now():%Y%m%d_%H%M%S}.csv"
    with open(raw_path, "w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=_LOG_FIELDS)
        writer.writeheader()
        writer.writerows(results)

    summary = _compute_summary(results, manifest_name=manifest_path.name)
    summary_path = device_dir / "summary.csv"
    write_header = not summary_path.exists()
    with open(summary_path, "a", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=_SUMMARY_FIELDS)
        if write_header:
            writer.writeheader()
        writer.writerow(summary)

    print(f"Ham CSV (kisisel yol icerir, commit'lenmez): {raw_path}")
    print(f"Ozet CSV (commit'lenir)                    : {summary_path}")
    _print_summary(summary)


if __name__ == "__main__":
    main()
