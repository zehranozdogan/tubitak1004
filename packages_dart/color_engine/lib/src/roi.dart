// Reaktif hücre ROI örnekleme — packages/color_engine/roi.py'nin Dart
// portu (rapor §6.2 adım 4-5).

import 'homography.dart';
import 'types.dart';

/// Bir modülün merkez bölgesinden piksel yamasını (patch) döndürür.
/// `margin`: modül sınırından içeri kaç piksel çekileceği. Python tarafı
/// numpy dilimlemesiyle sınır dışını sessizce kırpıyordu — burada da aynı
/// davranış (clamp) uygulanır.
RgbImage sampleModuleRoi(
  RgbImage image,
  int row,
  int col, {
  required int scale,
  required int border,
  int margin = 2,
}) {
  final center = modulePixelCenter(row, col, scale: scale, border: border);
  final half = (scale ~/ 2 - margin) < 1 ? 1 : (scale ~/ 2 - margin);

  final x0 = (center.x - half).clamp(0, image.width);
  final x1 = (center.x + half + 1).clamp(0, image.width);
  final y0 = (center.y - half).clamp(0, image.height);
  final y1 = (center.y + half + 1).clamp(0, image.height);

  final w = x1 - x0;
  final h = y1 - y0;
  final pixels = <Rgb>[];
  for (var y = y0; y < y1; y++) {
    for (var x = x0; x < x1; x++) {
      pixels.add(image.at(x, y));
    }
  }
  return RgbImage(width: w, height: h, pixels: pixels);
}

double _median(List<double> values) {
  final sorted = [...values]..sort();
  final n = sorted.length;
  if (n.isOdd) return sorted[n ~/ 2];
  return (sorted[n ~/ 2 - 1] + sorted[n ~/ 2]) / 2.0;
}

/// Bir piksel yamasından MEDIAN ile sağlam bir temsilci RGB çıkarır —
/// aşırı parlak (glare) / aşırı karanlık (gölge) pikselleri eler. DİKKAT:
/// Python'daki `np.median(usable, axis=0)` gibi medyan HER KANAL İÇİN
/// BAĞIMSIZ hesaplanır (R'lerin medyanı, G'lerin medyanı, B'lerin medyanı
/// ayrı ayrı) — "en ortadaki piksel" gibi TEK bir piksel seçilmiyor, bu
/// yüzden sonuç kaynak piksellerin hiçbirine birebir eşit olmayabilir
/// (gerçek Python davranışıyla elle doğrulandı, bkz. test/roi_test.dart).
/// Tüm piksel yaması aykırıysa (elemeden hiçbir şey kalmazsa) yine de
/// bütün yamanın medyanı döner.
Rgb robustModuleColor(RgbImage patch, {double glareThreshold = 250, double shadowThreshold = 5}) {
  final usableR = <double>[];
  final usableG = <double>[];
  final usableB = <double>[];
  for (final p in patch.pixels) {
    final brightness = (p.r + p.g + p.b) / 3.0;
    if (brightness < glareThreshold && brightness > shadowThreshold) {
      usableR.add(p.r);
      usableG.add(p.g);
      usableB.add(p.b);
    }
  }
  if (usableR.isEmpty) {
    for (final p in patch.pixels) {
      usableR.add(p.r);
      usableG.add(p.g);
      usableB.add(p.b);
    }
  }
  return Rgb(_median(usableR), _median(usableG), _median(usableB));
}
