// RGB <-> CIE Lab dönüşümü ve ΔE (CIEDE2000) — packages/color_engine/
// colorspace.py'nin Dart portu.
//
// Python tarafı scikit-image'ın rgb2lab/deltaE_ciede2000'ini kullanıyordu
// ("tekerlek yeniden icat edilmiyor" — hand-rolled CIEDE2000 hataya açık).
// Burada Dart'ta skimage yok, o yüzden algoritma BİREBİR skimage'ın kaynak
// kodundan (.venv/Lib/site-packages/skimage/color/colorconv.py::rgb2xyz/
// xyz2lab, delta_e.py::deltaE_ciede2000) elle port edildi — icat edilmedi,
// KOPYALANDI. Referans sayısal değerler (test/colorspace_test.dart) de
// gerçek Python fonksiyonu çalıştırılarak üretildi, tahmin edilmedi.
//
// ignore_for_file: non_constant_identifier_names -- L1/C1/Lbar/SL/SC/CC/
// Hbar/SH/Rc gibi isimler CIEDE2000'in kendi standart matematiksel
// gösterimini (ve Python kaynağındaki isimleri) BİREBİR takip ediyor —
// formülü kaynakla karşılaştırmayı kolaylaştırmak için kasıtlı.

import 'dart:math' as math;

import 'types.dart';

// sRGB -> XYZ matrisi (skimage: "From sRGB specification", xyz_from_rgb).
const List<List<double>> _xyzFromRgb = [
  [0.412453, 0.357580, 0.180423],
  [0.212671, 0.715160, 0.072169],
  [0.019334, 0.119193, 0.950227],
];

// D65, 2° gözlemci referans beyazı (skimage: _illuminants["D65"]["2"]).
const double _refX = 0.95047;
const double _refY = 1.0;
const double _refZ = 1.08883;

double _inverseSrgbGamma(double c) {
  return c > 0.04045 ? math.pow((c + 0.055) / 1.055, 2.4).toDouble() : c / 12.92;
}

double _labF(double t) {
  return t > 0.008856 ? math.pow(t, 1 / 3).toDouble() : 7.787 * t + 16.0 / 116.0;
}

/// sRGB (0-255 kanal) -> CIE Lab (D65 aydınlatıcı, skimage varsayılanları
/// ile BİREBİR aynı — bkz. dosya başlığı).
Lab rgbToLab(Rgb rgb) {
  final rLin = _inverseSrgbGamma(rgb.r / 255.0);
  final gLin = _inverseSrgbGamma(rgb.g / 255.0);
  final bLin = _inverseSrgbGamma(rgb.b / 255.0);

  final x = _xyzFromRgb[0][0] * rLin + _xyzFromRgb[0][1] * gLin + _xyzFromRgb[0][2] * bLin;
  final y = _xyzFromRgb[1][0] * rLin + _xyzFromRgb[1][1] * gLin + _xyzFromRgb[1][2] * bLin;
  final z = _xyzFromRgb[2][0] * rLin + _xyzFromRgb[2][1] * gLin + _xyzFromRgb[2][2] * bLin;

  final fx = _labF(x / _refX);
  final fy = _labF(y / _refY);
  final fz = _labF(z / _refZ);

  final L = 116.0 * fy - 16.0;
  final a = 500.0 * (fx - fy);
  final b = 200.0 * (fy - fz);
  return Lab(L, a, b);
}

/// Kartezyen (x, y) -> kutupsal (r, theta), theta ARALIĞI (0, 2*pi) —
/// skimage'ın _cart2polar_2pi'siyle BİREBİR aynı (standart atan2 aralığı
/// (-pi, pi) DEĞİL, CIEDE2000'in kendi sözleşmesi).
({double r, double theta}) _cart2polar2pi(double x, double y) {
  final r = math.sqrt(x * x + y * y);
  var t = math.atan2(y, x);
  if (t < 0.0) t += 2 * math.pi;
  return (r: r, theta: t);
}

double _deg2rad(double deg) => deg * math.pi / 180.0;
double _rad2deg(double rad) => rad * 180.0 / math.pi;

/// CIEDE2000 renk farkı. 0 = özdeş; ~1 civarı "zor fark edilir" eşiği,
/// büyüdükçe fark büyür. Algoritma skimage.color.deltaE_ciede2000 ile
/// BİREBİR aynı (bkz. dosya başlığı) — kL=kC=kH=1 (Python tarafındaki
/// varsayılanlarla aynı, delta_e.py::delta_e() hep varsayılanla çağırıyordu).
double deltaE(Lab lab1, Lab lab2) {
  final L1 = lab1.L, a1 = lab1.a, b1 = lab1.b;
  final L2 = lab2.L, a2 = lab2.a, b2 = lab2.b;

  // G / ölçek: ORİJİNAL (bozulmamış) a,b'den hesaplanan ortalama kroma.
  final c1Orig = math.sqrt(a1 * a1 + b1 * b1);
  final c2Orig = math.sqrt(a2 * a2 + b2 * b2);
  final cbarOrig = 0.5 * (c1Orig + c2Orig);
  final c7Orig = math.pow(cbarOrig, 7).toDouble();
  final g = 0.5 * (1 - math.sqrt(c7Orig / (c7Orig + math.pow(25, 7))));
  final scale = 1 + g;

  final p1 = _cart2polar2pi(a1 * scale, b1);
  final p2 = _cart2polar2pi(a2 * scale, b2);
  final C1 = p1.r, h1 = p1.theta;
  final C2 = p2.r, h2 = p2.theta;

  // Lightness term
  final Lbar = 0.5 * (L1 + L2);
  final tmp = math.pow(Lbar - 50, 2).toDouble();
  final SL = 1 + 0.015 * tmp / math.sqrt(20 + tmp);
  final lTerm = (L2 - L1) / SL;

  // Chroma term — DİKKAT: Cbar burada (ölçeklenmiş/kutupsal) C1,C2'den
  // yeniden hesaplanıyor, yukarıdaki cbarOrig'den FARKLI (Python'da da
  // aynı isim `Cbar` yeniden atanıyordu — burada karışmasın diye ayrı
  // isimlendirildi).
  final cbarPrime = 0.5 * (C1 + C2);
  final SC = 1 + 0.045 * cbarPrime;
  final cTerm = (C2 - C1) / SC;

  // Hue term
  final hDiff = h2 - h1;
  final hSum = h1 + h2;
  final CC = C1 * C2;

  var dH = hDiff;
  if (hDiff > math.pi) dH -= 2 * math.pi;
  if (hDiff < -math.pi) dH += 2 * math.pi;
  if (CC == 0.0) dH = 0.0;
  final dHTerm = 2 * math.sqrt(CC) * math.sin(dH / 2);

  var Hbar = hSum;
  final mask = CC != 0.0 && hDiff.abs() > math.pi;
  if (mask && hSum < 2 * math.pi) Hbar += 2 * math.pi;
  if (mask && hSum >= 2 * math.pi) Hbar -= 2 * math.pi;
  if (CC == 0.0) Hbar *= 2;
  Hbar *= 0.5;

  final T = 1 -
      0.17 * math.cos(Hbar - _deg2rad(30)) +
      0.24 * math.cos(2 * Hbar) +
      0.32 * math.cos(3 * Hbar + _deg2rad(6)) -
      0.20 * math.cos(4 * Hbar - _deg2rad(63));
  final SH = 1 + 0.015 * cbarPrime * T;
  final hTerm = dHTerm / SH;

  // Hue rotation
  final c7Prime = math.pow(cbarPrime, 7).toDouble();
  final Rc = 2 * math.sqrt(c7Prime / (c7Prime + math.pow(25, 7)));
  final dtheta = _deg2rad(30) * math.exp(-math.pow((_rad2deg(Hbar) - 275) / 25, 2));
  final rTerm = -math.sin(2 * dtheta) * Rc * cTerm * hTerm;

  final dE2 = lTerm * lTerm + cTerm * cTerm + hTerm * hTerm + rTerm;
  return math.sqrt(math.max(dE2, 0));
}
