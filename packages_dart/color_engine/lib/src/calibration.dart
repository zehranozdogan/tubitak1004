// Kalibrasyon yöntem aileleri — packages/color_engine/calibration.py'nin
// Dart portu (rapor §6.1 A-E).
//
// Python tarafı numpy dizileri (H, W, 3) üzerinde çalışıyordu; burada
// henüz bir "görüntü" temsili (Flutter'da hangi paket/format kullanılacağı
// — homografi/ROI portu sırasında karar verilecek) seçilmediği için
// piksel listesi (`List<Rgb>`) kullanılıyor — matematiksel olarak
// BİREBİR aynı (her işlem ya piksel-bağımsız/eleman-bazlı ya da tüm
// piksellerin toplu istatistiğine dayanıyor, 2D dizilim önemli değil).
//
// Sayısal davranış notu: Python `.astype(np.uint8)` KIRPAR (yuvarlamaz,
// sıfıra doğru keser) — burada da `.toInt()` kullanılıyor (Dart'ta pozitif
// double'larda floor ile aynı), aksi halde referans değerlerle
// (test/calibration_test.dart, gerçek Python'dan üretildi) piksel piksel
// eşleşmez (elle doğrulandı: (125-10)/230*255=127.5 Python'da 127 veriyor,
// 128 değil).

import 'dart:math' as math;

import 'linalg.dart';
import 'types.dart';

int _clipToByte(double v) => v.clamp(0.0, 255.0).toInt();

/// Beyaz + siyah iki noktalı referans kalibrasyonu (rapor §6.1 A).
/// Her kanalı bağımsız doğrusal esnetir: black -> 0, white -> 255.
List<Rgb> whiteBlack(List<Rgb> pixels, {required Rgb white, required Rgb black}) {
  final spanR = white.r - black.r == 0 ? 1.0 : white.r - black.r;
  final spanG = white.g - black.g == 0 ? 1.0 : white.g - black.g;
  final spanB = white.b - black.b == 0 ? 1.0 : white.b - black.b;

  return pixels
      .map((p) => Rgb(
            _clipToByte((p.r - black.r) / spanR * 255.0).toDouble(),
            _clipToByte((p.g - black.g) / spanG * 255.0).toDouble(),
            _clipToByte((p.b - black.b) / spanB * 255.0).toDouble(),
          ))
      .toList();
}

/// Beyaz + gri + siyah üç noktalı referans kalibrasyonu (rapor §6.1 B).
/// A ile aynı uç-nokta normalizasyonu + gri referansın orta tona (0.5)
/// oturacağı bir gama (üs) çözülüp uygulanır.
List<Rgb> whiteGrayBlack(
  List<Rgb> pixels, {
  required Rgb white,
  required Rgb gray,
  required Rgb black,
}) {
  final spanR = white.r - black.r == 0 ? 1.0 : white.r - black.r;
  final spanG = white.g - black.g == 0 ? 1.0 : white.g - black.g;
  final spanB = white.b - black.b == 0 ? 1.0 : white.b - black.b;

  double normalizedGray(double gray, double black, double span) {
    return ((gray - black) / span).clamp(1e-6, 1 - 1e-6);
  }

  final gammaR = math.log(0.5) / math.log(normalizedGray(gray.r, black.r, spanR));
  final gammaG = math.log(0.5) / math.log(normalizedGray(gray.g, black.g, spanG));
  final gammaB = math.log(0.5) / math.log(normalizedGray(gray.b, black.b, spanB));

  double correct(double c, double black, double span, double gamma) {
    final normalized = ((c - black) / span).clamp(0.0, 1.0);
    return _clipToByte(math.pow(normalized, gamma).toDouble() * 255.0).toDouble();
  }

  return pixels
      .map((p) => Rgb(
            correct(p.r, black.r, spanR, gammaR),
            correct(p.g, black.g, spanG, gammaG),
            correct(p.b, black.b, spanB, gammaB),
          ))
      .toList();
}

/// QR'ın kendi sabit siyah/beyaz modüllerini referans alan kalibrasyon
/// (rapor §6.1 D) — matematiksel olarak `whiteBlack` ile AYNIDIR, tek fark
/// referans renklerin nereden geldiği (ek baskı yaması gerektirmez).
List<Rgb> qrFixedRegions(List<Rgb> pixels, {required Rgb white, required Rgb black}) {
  return whiteBlack(pixels, white: white, black: black);
}

/// Algoritmik white balance / "gray-world" varsayımı (rapor §6.1 E).
/// Referans yaması gerektirmez: her kanal, üç kanalın ortak ortalamasına
/// eşitlenecek şekilde ayrı ayrı ölçeklenir.
List<Rgb> algorithmicWhiteBalance(List<Rgb> pixels) {
  var sumR = 0.0, sumG = 0.0, sumB = 0.0;
  for (final p in pixels) {
    sumR += p.r;
    sumG += p.g;
    sumB += p.b;
  }
  final n = pixels.length;
  var meanR = sumR / n, meanG = sumG / n, meanB = sumB / n;
  if (meanR == 0) meanR = 1.0;
  if (meanG == 0) meanG = 1.0;
  if (meanB == 0) meanB = 1.0;
  final grayMean = (meanR + meanG + meanB) / 3.0;
  final gainR = grayMean / meanR, gainG = grayMean / meanG, gainB = grayMean / meanB;

  return pixels
      .map((p) => Rgb(
            _clipToByte(p.r * gainR).toDouble(),
            _clipToByte(p.g * gainG).toDouble(),
            _clipToByte(p.b * gainB).toDouble(),
          ))
      .toList();
}

/// Çoklu sabit renk yaması ile 3x4 afin renk düzeltme (rapor §6.1 C).
/// En az 4 (captured, true) nokta çifti gerekir. En küçük kareler ile
/// normal denklemler ([captured|1]^T[captured|1]) x = [captured|1]^T[true]
/// çözülür — numpy.linalg.lstsq ile aynı SONUCU verir (aynı problem,
/// farklı çözüm yolu: Python SVD tabanlı lstsq kullanıyor, burada normal
/// denklemler + Gauss-Jordan — tekil olmayan/iyi-koşullu 4 nokta için
/// matematiksel olarak eşdeğer, elle gerçek Python çıktısıyla
/// karşılaştırılarak doğrulandı, bkz. test/calibration_test.dart).
class MulticolorPatchFit {
  /// 4x3 matris — [captured_r, captured_g, captured_b, 1] @ matrix = corrected.
  final List<List<double>> matrix;
  const MulticolorPatchFit(this.matrix);
}

MulticolorPatchFit fitMulticolorPatch({
  required List<Rgb> captured,
  required List<Rgb> trueColors,
}) {
  if (captured.length < 4) {
    throw ArgumentError('multicolor_patch en az 4 referans noktası gerektirir (3x4 afin çözüm için).');
  }
  // design: Nx4 ([r,g,b,1]); target: Nx3
  final n = captured.length;
  final design = List.generate(n, (i) => [captured[i].r, captured[i].g, captured[i].b, 1.0]);
  final target = List.generate(n, (i) => [trueColors[i].r, trueColors[i].g, trueColors[i].b]);

  // AtA (4x4) ve AtB (4x3)
  final ata = List.generate(4, (_) => List.filled(4, 0.0));
  final atb = List.generate(4, (_) => List.filled(3, 0.0));
  for (var row = 0; row < n; row++) {
    for (var i = 0; i < 4; i++) {
      for (var j = 0; j < 4; j++) {
        ata[i][j] += design[row][i] * design[row][j];
      }
      for (var j = 0; j < 3; j++) {
        atb[i][j] += design[row][i] * target[row][j];
      }
    }
  }

  final matrix = solveLinearSystem(ata, atb);
  return MulticolorPatchFit(matrix);
}

List<Rgb> applyMulticolorPatch(List<Rgb> pixels, MulticolorPatchFit fit) {
  final m = fit.matrix;
  return pixels.map((p) {
    final r = p.r * m[0][0] + p.g * m[1][0] + p.b * m[2][0] + m[3][0];
    final g = p.r * m[0][1] + p.g * m[1][1] + p.b * m[2][1] + m[3][1];
    final b = p.r * m[0][2] + p.g * m[1][2] + p.b * m[2][2] + m[3][2];
    return Rgb(_clipToByte(r).toDouble(), _clipToByte(g).toDouble(), _clipToByte(b).toDouble());
  }).toList();
}
