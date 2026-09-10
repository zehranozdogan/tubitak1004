"""color_engine — renk kalibrasyonu, ROI ölçümü ve profile göre eşleştirme.

Rapor §6.2 akışı:
  1. QR/etiket tespiti ve köşe koordinatları
  2. Homografi ile standart koordinat sistemine hizalama
  3. Seçilen kalibrasyon yönteminin uygulanması (§6.1 A–E)
  4. Reaktif hücrelerin merkez ROI'lerinden piksel örnekleme (parlama/gölge/kenar eleme)
  5. median / trimmed mean; gerekirse GMM / K-Means dominant renk
  6. RGB + CIE Lab birlikte; renk farkı CIEDE2000 (veya doğrulanmış metrik)
  7. sensor_profile.scale_points ile eşleştirme
  8. Görüntü kalitesi yetersizse "Yeniden tara" (yanlış güvenli sonuç üretme)

Standart çıktı (rapor §10.2): ColorEngineResult.

DURUM: iskelet. pipeline.analyze() gerçek görüntü işleme YAPMAZ; düşük kaliteli
placeholder döndürür. numpy/opencv eklenince adım adım doldurulacak.
"""

from packages.color_engine.pipeline import analyze
from packages.color_engine.quality import quality_score, should_rescan
from packages.color_engine.types import ColorEngineResult, Lab, ModuleReading, Rgb

__all__ = [
    "analyze",
    "ColorEngineResult",
    "ModuleReading",
    "Rgb",
    "Lab",
    "quality_score",
    "should_rescan",
]
