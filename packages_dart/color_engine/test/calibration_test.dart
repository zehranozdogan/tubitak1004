// calibration.dart testleri — REFERANS DEĞERLER gerçek Python
// packages/color_engine/calibration.py çalıştırılarak üretildi
// (bkz. sohbet geçmişi, 22 Eylül), TAHMİN EDİLMEDİ.

import 'package:color_engine/color_engine.dart';
import 'package:test/test.dart';

void expectRgb(Rgb actual, Rgb expected, {String? reason}) {
  expect(actual.r, closeTo(expected.r, 0.001), reason: reason);
  expect(actual.g, closeTo(expected.g, 0.001), reason: reason);
  expect(actual.b, closeTo(expected.b, 0.001), reason: reason);
}

void main() {
  final white = const Rgb(240, 235, 230);
  final black = const Rgb(10, 12, 15);

  group('whiteBlack', () {
    final pixels = const [
      Rgb(240, 235, 230),
      Rgb(10, 12, 15),
      Rgb(125, 120, 118),
      Rgb(255, 255, 255),
      Rgb(0, 0, 0),
      Rgb(200, 50, 30),
    ];
    final expected = const [
      Rgb(255, 255, 255),
      Rgb(0, 0, 0),
      Rgb(127, 123, 122),
      Rgb(255, 255, 255),
      Rgb(0, 0, 0),
      Rgb(210, 43, 17),
    ];

    test('gerçek Python çıktısıyla piksel piksel eşleşir', () {
      final out = whiteBlack(pixels, white: white, black: black);
      for (var i = 0; i < pixels.length; i++) {
        expectRgb(out[i], expected[i], reason: 'pixel $i (${pixels[i]})');
      }
    });
  });

  group('whiteGrayBlack', () {
    final gray = const Rgb(128, 124, 120);
    final pixels = const [
      Rgb(240, 235, 230),
      Rgb(10, 12, 15),
      Rgb(125, 120, 118),
      Rgb(255, 255, 255),
      Rgb(0, 0, 0),
      Rgb(200, 50, 30),
    ];
    final expected = const [
      Rgb(255, 255, 255),
      Rgb(0, 0, 0),
      Rgb(124, 122, 125),
      Rgb(255, 255, 255),
      Rgb(0, 0, 0),
      Rgb(209, 42, 19),
    ];

    test('gerçek Python çıktısıyla piksel piksel eşleşir', () {
      final out = whiteGrayBlack(pixels, white: white, gray: gray, black: black);
      for (var i = 0; i < pixels.length; i++) {
        expectRgb(out[i], expected[i], reason: 'pixel $i (${pixels[i]})');
      }
    });
  });

  group('qrFixedRegions', () {
    test('whiteBlack ile matematiksel olarak özdeştir (rapor §6.1 D)', () {
      final pixels = const [Rgb(200, 50, 30), Rgb(125, 120, 118)];
      final a = whiteBlack(pixels, white: white, black: black);
      final b = qrFixedRegions(pixels, white: white, black: black);
      for (var i = 0; i < pixels.length; i++) {
        expectRgb(b[i], a[i]);
      }
    });
  });

  group('algorithmicWhiteBalance', () {
    // channel means: (201.25, 101.25, 51.25) — gerçek Python çıktısı.
    final pixels = const [
      Rgb(200, 100, 50),
      Rgb(210, 110, 60),
      Rgb(190, 90, 40),
      Rgb(205, 105, 55),
    ];
    final expected = const [
      Rgb(117, 116, 115),
      Rgb(123, 128, 138),
      Rgb(111, 104, 92),
      Rgb(120, 122, 126),
    ];

    test('gerçek Python çıktısıyla piksel piksel eşleşir', () {
      final out = algorithmicWhiteBalance(pixels);
      for (var i = 0; i < pixels.length; i++) {
        expectRgb(out[i], expected[i], reason: 'pixel $i (${pixels[i]})');
      }
    });
  });

  group('multicolorPatch (fitMulticolorPatch + applyMulticolorPatch)', () {
    final captured = const [
      Rgb(240, 235, 230),
      Rgb(10, 12, 15),
      Rgb(128, 124, 120),
      Rgb(200, 60, 50),
      Rgb(50, 180, 70),
      Rgb(60, 70, 190),
    ];
    final trueColors = const [
      Rgb(255, 255, 255),
      Rgb(0, 0, 0),
      Rgb(128, 128, 128),
      Rgb(205, 40, 40),
      Rgb(35, 150, 70),
      Rgb(35, 95, 190),
    ];

    // numpy.linalg.lstsq'nun gerçek çıktısı — normal denklemler/Gauss-Jordan
    // çözümümüzün DOĞRU problemi çözdüğünü kanıtlamak için ayrıca kontrol
    // ediliyor (sadece nihai piksel çıktısı değil, ara matris de).
    final expectedMatrix = [
      [1.15168970e+00, -7.38155994e-03, 1.74658702e-02],
      [3.28553351e-02, 8.52281651e-01, 9.06605657e-02],
      [-6.66987231e-02, 3.22272079e-01, 1.08057106e+00],
      [-1.86192263e+01, -2.08098241e+01, -2.00236382e+01],
    ];

    test('fitlenen 4x3 matris gerçek numpy.linalg.lstsq çıktısıyla eşleşir', () {
      final fit = fitMulticolorPatch(captured: captured, trueColors: trueColors);
      for (var i = 0; i < 4; i++) {
        for (var j = 0; j < 3; j++) {
          expect(
            fit.matrix[i][j],
            closeTo(expectedMatrix[i][j], 1e-3),
            reason: 'matrix[$i][$j]',
          );
        }
      }
    });

    test('düzeltilmiş pikseller gerçek Python çıktısıyla eşleşir', () {
      final fit = fitMulticolorPatch(captured: captured, trueColors: trueColors);
      final testPixels = const [
        Rgb(240, 235, 230),
        Rgb(10, 12, 15),
        Rgb(128, 124, 120),
        Rgb(150, 100, 80),
      ];
      final expected = const [
        Rgb(250, 251, 254),
        Rgb(0, 0, 0),
        Rgb(124, 122, 123),
        Rgb(152, 89, 78),
      ];
      final out = applyMulticolorPatch(testPixels, fit);
      for (var i = 0; i < testPixels.length; i++) {
        expectRgb(out[i], expected[i], reason: 'pixel $i (${testPixels[i]})');
      }
    });

    test('4 noktadan az referansta hata fırlatır (Python: ValueError)', () {
      expect(
        () => fitMulticolorPatch(captured: captured.sublist(0, 3), trueColors: trueColors.sublist(0, 3)),
        throwsArgumentError,
      );
    });
  });
}
