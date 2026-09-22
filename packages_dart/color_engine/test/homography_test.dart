// homography.dart testleri — REFERANS DEĞERLER gerçek Python (cv2)
// çalıştırılarak üretildi (bkz. sohbet geçmişi, 22 Eylül), TAHMİN EDİLMEDİ.

import 'package:color_engine/color_engine.dart';
import 'package:test/test.dart';

void main() {
  test('canonicalSize gerçek Python canonical_size ile eşleşir', () {
    expect(canonicalSize(25, scale: 10, border: 4), 330);
  });

  test('canonicalQrCorners gerçek Python canonical_qr_corners ile eşleşir', () {
    final corners = canonicalQrCorners(25, scale: 10, border: 4);
    expect(corners, [
      [40.0, 40.0],
      [290.0, 40.0],
      [290.0, 290.0],
      [40.0, 290.0],
    ]);
  });

  group('getPerspectiveTransform', () {
    // src: hafif eğik/perspektifli 4 köşe (bir fotoğrafı simüle eder).
    final src = [
      [15.0, 20.0],
      [330.0, 5.0],
      [340.0, 345.0],
      [10.0, 330.0],
    ];
    final dst = canonicalQrCorners(25, scale: 10, border: 4);

    // cv2.getPerspectiveTransform'un GERÇEK çıktısı.
    final expectedMatrix = [
      [8.88353616e-01, 2.01473410e-02, 2.65778102e+01],
      [5.28383594e-02, 8.55662598e-01, 2.24002340e+01],
      [3.09478179e-04, 1.50468006e-04, 1.00000000e+00],
    ];

    test('3x3 matris gerçek cv2 çıktısıyla eşleşir', () {
      final m = getPerspectiveTransform(src, dst);
      for (var i = 0; i < 3; i++) {
        for (var j = 0; j < 3; j++) {
          expect(m[i][j], closeTo(expectedMatrix[i][j], 1e-6), reason: 'm[$i][$j]');
        }
      }
    });

    test('4 noktadan azında/çoğunda hata fırlatır', () {
      expect(() => getPerspectiveTransform(src.sublist(0, 3), dst.sublist(0, 3)), throwsArgumentError);
    });
  });

  group('warpToCanonical (uçtan uca, gerçek cv2.warpPerspective ile karşılaştırıldı)', () {
    // Python'daki TAM AYNI gradyan test görüntüsü: img[y,x] = [(x*255)//349, (y*255)//349, 128]
    RgbImage buildGradientImage() {
      const size = 350;
      final pixels = List<Rgb>.filled(size * size, const Rgb(0, 0, 0));
      for (var y = 0; y < size; y++) {
        for (var x = 0; x < size; x++) {
          pixels[y * size + x] = Rgb(
            ((x * 255) ~/ 349).toDouble(),
            ((y * 255) ~/ 349).toDouble(),
            128,
          );
        }
      }
      return RgbImage(width: size, height: size, pixels: pixels);
    }

    final src = [
      [15.0, 20.0],
      [330.0, 5.0],
      [340.0, 345.0],
      [10.0, 330.0],
    ];

    test('warped boyutu doğru', () {
      final warped = warpToCanonical(buildGradientImage(), src, matrixSize: 25, scale: 10, border: 4);
      expect(warped.width, 330);
      expect(warped.height, 330);
    });

    // (x, y, beklenen [r,g,b]) — gerçek cv2.warpPerspective çıktısından.
    final referencePoints = <(int x, int y, Rgb expected)>[
      (0, 0, const Rgb(0, 0, 0)),
      (5, 5, const Rgb(0, 0, 0)),
      (40, 40, const Rgb(10, 14, 128)),
      (165, 165, const Rgb(121, 124, 128)),
      (329, 329, const Rgb(0, 0, 0)),
      (100, 50, const Rgb(62, 21, 128)),
    ];

    for (final (x, y, expected) in referencePoints) {
      test('warped[$y,$x] gerçek cv2 çıktısıyla eşleşir', () {
        final warped = warpToCanonical(buildGradientImage(), src, matrixSize: 25, scale: 10, border: 4);
        final actual = warped.at(x, y);
        // Bilinear enterpolasyonda yuvarlama farkları (cv2 kendi iç
        // yuvarlama kuralını kullanıyor) olabileceğinden tolerans 2/255.
        expect(actual.r, closeTo(expected.r, 2), reason: 'r at ($x,$y)');
        expect(actual.g, closeTo(expected.g, 2), reason: 'g at ($x,$y)');
        expect(actual.b, closeTo(expected.b, 2), reason: 'b at ($x,$y)');
      });
    }
  });
}
