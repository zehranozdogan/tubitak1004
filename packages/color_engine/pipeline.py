"""Renk motoru ana akışı (rapor §6.2).

`image`: BGR numpy dizisi (decode.py/quality.py ile aynı sözleşme).

`layout_version.reference_regions` artık üretici tarafında dolduruluyor
(qr_layout/reactive.py::build_layout(), varsayılan: QR'ın finder pattern
sabitleri — D yöntemi, ek baskılı yama gerektirmez, reaktif hücreler bu
sabit bölgeye dokunmaz, §5.1). Eski/elle kurulmuş layout_version'larda bu
alan yoksa QR sabitlerine düşülür (geriye dönük uyumluluk).

Bilinen sınırlama: gri/çoklu-yama referansı gerektiren yöntemler (B, C)
hâlâ `white_black`'e (A) düşer — bunlar ya fiziksel ek baskı yaması ya da
kasıtlı hata modülü (`intentional_errors`, §5.2/4, henüz uygulanmadı)
gerektiriyor; `confidence` için de henüz doğrulanmış bir formül yok
(None döner).
"""

from __future__ import annotations

import numpy as np

from packages.color_engine import calibration
from packages.color_engine.colorspace import rgb_to_lab
from packages.color_engine.homography import warp_to_canonical
from packages.color_engine.matching import match_profile_point
from packages.color_engine.quality import quality_score, should_rescan
from packages.color_engine.roi import robust_module_color, sample_module_roi
from packages.color_engine.types import ColorEngineResult, ModuleReading, Rgb
from packages.qr_layout.colors import FINDER_BLACK_MODULE, FINDER_WHITE_MODULE
from packages.qr_layout.decode import decode_qr_image_with_corners

Image = np.ndarray

# Canonical (homografi sonrası) görüntünün rasterize parametreleri —
# packages.qr_layout.render'daki üretici varsayılanlarıyla AYNI olmalı.
_CANONICAL_SCALE = 10
_CANONICAL_BORDER = 4

# reference_regions dolmadan doğrudan (yalnızca beyaz/siyah referansla)
# çalışabilen yöntemler. Diğerleri (B, C, learned) white_black'e düşer.
_SUPPORTED_WITHOUT_EXTRA_REFERENCES = {"white_black", "qr_fixed_regions", "algorithmic_white_balance"}


def _rescan_result(quality: float, note: str) -> ColorEngineResult:
    return ColorEngineResult(quality_score=quality, rescan_recommended=True, notes=[note])


def analyze(
    image: Image,
    sensor_profile: dict,
    layout_version: dict,
    *,
    qr_corners: list[tuple[float, float]] | None = None,
) -> ColorEngineResult:
    """Tek bir kareden tazelik/teknik sonucu üretir (rapor §6.2 adım 1-8)."""
    # 8 (önce kontrol edilir — kötü görüntüde diğer adımlara hiç girilmez, §7.1).
    min_quality = (sensor_profile.get("quality_gate") or {}).get("min_quality_score", 0.5)
    quality = quality_score(image)
    if should_rescan(quality, min_quality):
        return _rescan_result(quality, "Görüntü kalitesi yetersiz (bulanık/parlamalı/karanlık).")

    # 1. QR köşe tespiti (verilmemişse).
    if qr_corners is None:
        _text, qr_corners = decode_qr_image_with_corners(image)
    if qr_corners is None:
        return _rescan_result(quality, "QR köşeleri tespit edilemedi.")

    sensor_modules = layout_version.get("sensor_modules") or []
    if not sensor_modules:
        return _rescan_result(quality, "layout_version.sensor_modules boş; ölçülecek reaktif hücre yok.")

    # 2. Homografi -> canonical görüntü.
    matrix_size = layout_version["matrix_size"]
    canonical = warp_to_canonical(
        image, qr_corners, matrix_size=matrix_size, scale=_CANONICAL_SCALE, border=_CANONICAL_BORDER
    )

    # 3. Kalibrasyon — referans modül konumları layout_version.reference_regions'tan
    #    okunur (§10.1: "okuyucu koordinatları hard-code etmez, bu dosyadan okur").
    #    Eski/elle kurulmuş layout_version'larda bu alan yoksa (geriye dönük
    #    uyumluluk) QR'ın finder pattern sabitlerine düşülür — build_layout()
    #    artık bunu otomatik dolduruyor, bkz. qr_layout/reactive.py.
    notes: list[str] = []
    code = (sensor_profile.get("calibration_method") or {}).get("code", "white_black")
    if code not in _SUPPORTED_WITHOUT_EXTRA_REFERENCES:
        notes.append(
            f"Kalibrasyon yöntemi '{code}' ek referans (gri/çoklu-yama) gerektiriyor; "
            "layout_version.reference_regions bu anahtarları içermediği için white_black'e düşüldü."
        )
        code = "white_black"

    ref_regions = layout_version.get("reference_regions") or {}
    white_pos = tuple(ref_regions["white"][0]) if ref_regions.get("white") else FINDER_WHITE_MODULE
    black_pos = tuple(ref_regions["black"][0]) if ref_regions.get("black") else FINDER_BLACK_MODULE

    white_ref = robust_module_color(
        sample_module_roi(canonical, *white_pos, scale=_CANONICAL_SCALE, border=_CANONICAL_BORDER)
    )
    black_ref = robust_module_color(
        sample_module_roi(canonical, *black_pos, scale=_CANONICAL_SCALE, border=_CANONICAL_BORDER)
    )
    apply_calibration = calibration.get(code)
    if code == "algorithmic_white_balance":
        corrected = apply_calibration(canonical)
    else:
        corrected = apply_calibration(canonical, {"white": tuple(white_ref), "black": tuple(black_ref)})

    # `image`/`canonical`/`corrected` BGR sırasındadır (decode.py/quality.py
    # ile aynı sözleşme, kalibrasyon matematiği kanal sırasından bağımsızdır).
    # Rgb/Lab için buradan itibaren GERÇEK RGB sırasına çeviriyoruz.
    corrected_rgb = corrected[:, :, ::-1]

    # 4-5. Reaktif hücrelerin ROI örneklemesi (parlama/gölge elenmiş median).
    module_readings: list[ModuleReading] = []
    rgb_samples: list[np.ndarray] = []
    for row, col in sensor_modules:
        patch = sample_module_roi(corrected_rgb, row, col, scale=_CANONICAL_SCALE, border=_CANONICAL_BORDER)
        rgb = robust_module_color(patch)
        rgb_samples.append(rgb)
        lab = rgb_to_lab(Rgb(*rgb))
        module_readings.append(ModuleReading(module=(row, col), normalized_color=Rgb(*rgb), lab=lab))

    # 6. Temsilci renk: modüller arası median (RGB) + Lab.
    representative_rgb = np.median(np.array(rgb_samples), axis=0)
    representative_lab = rgb_to_lab(Rgb(*representative_rgb))

    # 7. sensor_profile.scale_points ile eşleştirme (§7.2 sınıf kuralı dahil).
    match = match_profile_point(representative_lab, sensor_profile)

    return ColorEngineResult(
        quality_score=quality,
        rescan_recommended=False,
        normalized_color=Rgb(*representative_rgb),
        lab=representative_lab,
        delta_e=match["delta_e"],
        matched_profile_point=match["matched_profile_point"],
        freshness_class=match["freshness_class"],
        technical_level=match["technical_level"],
        confidence=None,  # TODO: doğrulanmış bir güven skoru formülü henüz yok
        module_readings=module_readings,
        notes=notes,
    )
