"""Ölçülen rengi sensor_profile.scale_points ile eşleştirme (rapor §6.2 adım 7).

Sonuç ekranı kuralı (§7.2, kritik): `class_thresholds` tanımlı değilse
(bilimsel eşik yok) `freshness_class` HER ZAMAN None döner — eşleşen
scale_point'in kendi `state` alanı dolu olsa bile. Uydurma sınıf yok.
"""

from __future__ import annotations

import numpy as np

from packages.color_engine.colorspace import delta_e
from packages.color_engine.types import Lab


def match_profile_point(measured_lab: Lab, sensor_profile: dict) -> dict:
    """En yakın `scale_point`'i ΔE (CIEDE2000) ile bulur.

    Döner: {"matched_profile_point": değer, "delta_e": en yakın ΔE,
    "freshness_class": str | None, "technical_level": str}.
    """
    scale_points = sensor_profile.get("scale_points") or []
    if not scale_points:
        raise ValueError("sensor_profile.scale_points boş olamaz.")

    distances = [delta_e(measured_lab, Lab(*point["lab"])) for point in scale_points]
    best_index = int(np.argmin(distances))
    best_point = scale_points[best_index]

    freshness_class = None
    if sensor_profile.get("class_thresholds") is not None:
        freshness_class = best_point.get("state")

    return {
        "matched_profile_point": best_point["value"],
        "delta_e": float(distances[best_index]),
        "freshness_class": freshness_class,
        "technical_level": f"Renk seviyesi {best_index + 1} / Profil noktası P{best_index + 1}",
    }
