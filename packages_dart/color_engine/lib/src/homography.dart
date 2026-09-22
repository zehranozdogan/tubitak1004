// Homografi ile canonical koordinat sistemine hizalama —
// packages/color_engine/homography.py'nin Dart portu (rapor §6.2 adım 2).
//
// cv2.getPerspectiveTransform (4 nokta karşılığından 3x3 matris çözümü) ve
// cv2.warpPerspective (INTER_LINEAR + BORDER_CONSTANT=0 varsayılanlarıyla,
// GERİYE doğru örnekleme: her hedef piksel için ters matrisle kaynak
// koordinatı bulunup bilinear örneklenir) elle port edildi — dış bağımlılık
// yok. Gerçek Python (`cv2`) çalıştırılıp hem ara matris hem nihai piksel
// değerleri karşılaştırılarak doğrulandı (bkz. test/homography_test.dart).

import 'linalg.dart';
import 'types.dart';

/// Ham piksel verisi için minimal görüntü temsili — henüz Flutter tarafında
/// hangi görüntü kütüphanesi/formatı kullanılacağına karar verilmedi (bkz.
/// paket README'si), bu yüzden şimdilik basit bir RGB piksel ızgarası.
class RgbImage {
  final int width;
  final int height;
  final List<Rgb> pixels; // satır-öncelikli (row-major), uzunluk width*height

  RgbImage({required this.width, required this.height, required this.pixels})
      : assert(pixels.length == width * height);

  Rgb at(int x, int y) => pixels[y * width + x];

  static RgbImage filled(int width, int height, Rgb color) {
    return RgbImage(width: width, height: height, pixels: List.filled(width * height, color));
  }
}

/// Bir QR modülünün (satır, sütun) rasterize edilmiş görüntüdeki piksel
/// merkezi — packages/qr_layout/colors.py::module_pixel_center'ın portu.
/// Dönen (y, x) sırası, `RgbImage.at(x, y)` ile eşleşecek şekilde ayrı
/// alanlar olarak verilir.
({int y, int x}) modulePixelCenter(int row, int col, {required int scale, required int border}) {
  final x = (col + border) * scale + scale ~/ 2;
  final y = (row + border) * scale + scale ~/ 2;
  return (y: y, x: x);
}

/// Canonical (kare) görüntünün kenar uzunluğu (piksel).
int canonicalSize(int matrixSize, {int scale = 10, int border = 4}) {
  return (matrixSize + 2 * border) * scale;
}

/// Canonical görüntüde QR'ın 4 köşesi (sol-üst, sağ-üst, sağ-alt, sol-alt)
/// — `packages.qr_layout.render`'daki rasterize kuralıyla AYNI.
List<List<double>> canonicalQrCorners(int matrixSize, {int scale = 10, int border = 4}) {
  final n = matrixSize;
  return [
    [(border * scale).toDouble(), (border * scale).toDouble()],
    [((n + border) * scale).toDouble(), (border * scale).toDouble()],
    [((n + border) * scale).toDouble(), ((n + border) * scale).toDouble()],
    [(border * scale).toDouble(), ((n + border) * scale).toDouble()],
  ];
}

/// 4 (src, dst) nokta karşılığından 3x3 perspektif dönüşüm matrisini çözer
/// — cv2.getPerspectiveTransform ile BİREBİR aynı algoritma (h33=1 sabit,
/// 8 bilinmeyen için 8 doğrusal denklem).
List<List<double>> getPerspectiveTransform(List<List<double>> src, List<List<double>> dst) {
  if (src.length != 4 || dst.length != 4) {
    throw ArgumentError('getPerspectiveTransform tam olarak 4 nokta gerektirir.');
  }
  final a = List.generate(8, (_) => List.filled(8, 0.0));
  final b = List.generate(8, (_) => [0.0]);

  for (var i = 0; i < 4; i++) {
    final x = src[i][0], y = src[i][1];
    final X = dst[i][0], Y = dst[i][1];

    a[2 * i] = [x, y, 1, 0, 0, 0, -x * X, -y * X];
    b[2 * i][0] = X;

    a[2 * i + 1] = [0, 0, 0, x, y, 1, -x * Y, -y * Y];
    b[2 * i + 1][0] = Y;
  }

  final h = solveLinearSystem(a, b);
  return [
    [h[0][0], h[1][0], h[2][0]],
    [h[3][0], h[4][0], h[5][0]],
    [h[6][0], h[7][0], 1.0],
  ];
}

List<List<double>> _invert3x3(List<List<double>> m) {
  return solveLinearSystem(m, identityMatrix(3));
}

/// Kaynak görüntüdeki `srcCorners`'ı (sol-üst, sağ-üst, sağ-alt, sol-alt)
/// canonical (düz) görüntüye perspektif düzeltmesiyle taşır —
/// cv2.warpPerspective(..., INTER_LINEAR, BORDER_CONSTANT=0) ile BİREBİR
/// aynı: hedefteki her piksel için ters matrisle kaynak koordinatı bulunur,
/// kaynak sınırları dışına düşen komşular siyah (0,0,0) kabul edilir.
RgbImage warpToCanonical(
  RgbImage image,
  List<List<double>> qrCorners, {
  required int matrixSize,
  int scale = 10,
  int border = 4,
}) {
  final size = canonicalSize(matrixSize, scale: scale, border: border);
  final dst = canonicalQrCorners(matrixSize, scale: scale, border: border);
  final transform = getPerspectiveTransform(qrCorners, dst);
  final inv = _invert3x3(transform);

  final out = List<Rgb>.filled(size * size, const Rgb(0, 0, 0));
  for (var dy = 0; dy < size; dy++) {
    for (var dx = 0; dx < size; dx++) {
      final w = inv[2][0] * dx + inv[2][1] * dy + inv[2][2];
      final sx = (inv[0][0] * dx + inv[0][1] * dy + inv[0][2]) / w;
      final sy = (inv[1][0] * dx + inv[1][1] * dy + inv[1][2]) / w;
      out[dy * size + dx] = _bilinearSample(image, sx, sy);
    }
  }
  return RgbImage(width: size, height: size, pixels: out);
}

const Rgb _black = Rgb(0, 0, 0);

Rgb _pixelOrBorder(RgbImage image, int x, int y) {
  if (x < 0 || x >= image.width || y < 0 || y >= image.height) return _black;
  return image.at(x, y);
}

Rgb _bilinearSample(RgbImage image, double sx, double sy) {
  // Tamamen görüntü dışına düşen noktalar için erken çıkış (performans) —
  // sonuç zaten BORDER_CONSTANT=0 ile aynı olurdu.
  if (sx <= -1 || sx >= image.width || sy <= -1 || sy >= image.height) {
    return _black;
  }
  final x0 = sx.floor();
  final y0 = sy.floor();
  final fx = sx - x0;
  final fy = sy - y0;

  final p00 = _pixelOrBorder(image, x0, y0);
  final p10 = _pixelOrBorder(image, x0 + 1, y0);
  final p01 = _pixelOrBorder(image, x0, y0 + 1);
  final p11 = _pixelOrBorder(image, x0 + 1, y0 + 1);

  double blend(double a, double b, double c, double d) {
    final top = a * (1 - fx) + b * fx;
    final bottom = c * (1 - fx) + d * fx;
    return top * (1 - fy) + bottom * fy;
  }

  return Rgb(
    blend(p00.r, p10.r, p01.r, p11.r).clamp(0.0, 255.0).roundToDouble(),
    blend(p00.g, p10.g, p01.g, p11.g).clamp(0.0, 255.0).roundToDouble(),
    blend(p00.b, p10.b, p01.b, p11.b).clamp(0.0, 255.0).roundToDouble(),
  );
}
