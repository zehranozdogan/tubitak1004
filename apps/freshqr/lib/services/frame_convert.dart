// Kamera karesi (Android NV21 / iOS BGRA8888) -> color_engine'in RgbImage'i.
//
// color_engine HER ZAMAN gerçek RGB bekler (BGR yok, bkz. color_engine README).
// Dönüşüm çağıran tarafın işidir — burası o dönüşüm.
//
// Döndürme: ML Kit köşe noktalarını, `InputImageMetadata.rotation` ile
// DÖNDÜRÜLMÜŞ (dik) görüntünün koordinatlarında verir. Bu yüzden kareyi de
// aynı açıyla (saat yönünde) döndürüp dik hâle getiriyoruz ki köşeler ve
// piksel verisi AYNI koordinat sisteminde olsun. (Bu varsayım gerçek cihazda
// doğrulanmalı — bkz. README "kamera testi".)

import 'dart:typed_data';

import 'package:color_engine/color_engine.dart';

int _clamp255(double v) => v < 0 ? 0 : (v > 255 ? 255 : v.round());

/// (x, y) kaynak pikselinin, kare `rotation` derece (0/90/180/270, saat
/// yönü) döndürülünce düşeceği (x, y) ve yeni boyutlar.
({int width, int height}) rotatedSize(int width, int height, int rotation) {
  return switch (rotation % 360) {
    90 || 270 => (width: height, height: width),
    _ => (width: width, height: height),
  };
}

int _destIndex(int x, int y, int w, int h, int rotation) {
  final (int dx, int dy) = switch (rotation % 360) {
    90 => (h - 1 - y, x),
    180 => (w - 1 - x, h - 1 - y),
    270 => (y, w - 1 - x),
    _ => (x, y),
  };
  final size = rotatedSize(w, h, rotation);
  return dy * size.width + dx;
}

/// NV21 (Y düzlemi + araya girmiş VU) -> RGB. `bytesPerRow` Y satır adımı
/// (satır dolgusu olabilir); VU satır adımı da aynı varsayılır.
RgbImage nv21ToRgbImage(
  Uint8List nv21,
  int width,
  int height, {
  int? bytesPerRow,
  int rotation = 0,
}) {
  final stride = bytesPerRow ?? width;
  final ySize = stride * height;
  if (nv21.length < ySize + stride * (height ~/ 2)) {
    throw ArgumentError('NV21 verisi çok kısa: ${nv21.length} bayt, $width x $height için yetersiz');
  }
  final out = rotatedSize(width, height, rotation);
  final pixels = List<Rgb>.filled(out.width * out.height, const Rgb(0, 0, 0));
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final yv = nv21[y * stride + x].toDouble();
      final uvIndex = ySize + (y >> 1) * stride + (x & ~1);
      final v = nv21[uvIndex].toDouble() - 128;
      final u = nv21[uvIndex + 1].toDouble() - 128;
      pixels[_destIndex(x, y, width, height, rotation)] = Rgb(
        _clamp255(yv + 1.402 * v).toDouble(),
        _clamp255(yv - 0.344136 * u - 0.714136 * v).toDouble(),
        _clamp255(yv + 1.772 * u).toDouble(),
      );
    }
  }
  return RgbImage(width: out.width, height: out.height, pixels: pixels);
}

/// BGRA8888 (iOS) -> RGB.
RgbImage bgraToRgbImage(
  Uint8List bgra,
  int width,
  int height, {
  int? bytesPerRow,
  int rotation = 0,
}) {
  final stride = bytesPerRow ?? width * 4;
  if (bgra.length < stride * (height - 1) + width * 4) {
    throw ArgumentError('BGRA verisi çok kısa');
  }
  final out = rotatedSize(width, height, rotation);
  final pixels = List<Rgb>.filled(out.width * out.height, const Rgb(0, 0, 0));
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final i = y * stride + x * 4;
      pixels[_destIndex(x, y, width, height, rotation)] =
          Rgb(bgra[i + 2].toDouble(), bgra[i + 1].toDouble(), bgra[i].toDouble());
    }
  }
  return RgbImage(width: out.width, height: out.height, pixels: pixels);
}
