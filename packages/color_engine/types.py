"""color-engine giriş/çıkış tipleri (rapor §10.2 ortak sözleşme)."""

from __future__ import annotations

from dataclasses import dataclass, field


@dataclass
class Rgb:
    r: float
    g: float
    b: float

    def as_tuple(self) -> tuple[float, float, float]:
        return (self.r, self.g, self.b)


@dataclass
class Lab:
    L: float
    a: float
    b: float

    def as_tuple(self) -> tuple[float, float, float]:
        return (self.L, self.a, self.b)


@dataclass
class ModuleReading:
    """Tek bir reaktif hücrenin normalize edilmiş ölçümü."""

    module: tuple[int, int]
    normalized_color: Rgb
    lab: Lab
    delta_e: float | None = None
    matched_profile_point: float | None = None


@dataclass
class ColorEngineResult:
    """color-engine standart çıktısı (rapor §10.2).

    freshness_class None ise: bilimsel eşik yok -> uygulama sınıf göstermez,
    technical_level gösterir (rapor §7.2).
    """

    quality_score: float
    rescan_recommended: bool
    normalized_color: Rgb | None = None
    lab: Lab | None = None
    delta_e: float | None = None
    matched_profile_point: float | None = None
    freshness_class: str | None = None       # "fresh" | "transition" | "spoiled" | None
    technical_level: str | None = None        # ör. "Renk seviyesi 2 / Profil noktası P4"
    confidence: float | None = None
    module_readings: list[ModuleReading] = field(default_factory=list)
    notes: list[str] = field(default_factory=list)
