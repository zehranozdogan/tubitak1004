// roi.dart testleri — REFERANS DEĞERLER gerçek Python
// packages/color_engine/roi.py + packages/qr_layout/colors.py::
// module_pixel_center çalıştırılarak üretildi, TAHMİN EDİLMEDİ.

import 'package:color_engine/color_engine.dart';
import 'package:test/test.dart';

void main() {
  group('modulePixelCenter', () {
    test('gerçek Python module_pixel_center ile eşleşir', () {
      final c1 = modulePixelCenter(5, 7, scale: 10, border: 4);
      expect(c1.y, 95);
      expect(c1.x, 115);

      final c2 = modulePixelCenter(0, 0, scale: 10, border: 4);
      expect(c2.y, 45);
      expect(c2.x, 45);
    });
  });

  group('sampleModuleRoi', () {
    test('yama boyutu ve merkez pikseli gerçek Python çıktısıyla eşleşir', () {
      // Python: img[y,x] = [x%256, y%256, 100]
      const size = 200;
      final pixels = List<Rgb>.generate(
        size * size,
        (i) {
          final y = i ~/ size, x = i % size;
          return Rgb((x % 256).toDouble(), (y % 256).toDouble(), 100);
        },
      );
      final image = RgbImage(width: size, height: size, pixels: pixels);

      final patch = sampleModuleRoi(image, 5, 7, scale: 10, border: 4);
      expect(patch.width, 7);
      expect(patch.height, 7);

      final topLeft = patch.at(0, 0);
      expect(topLeft.r, 112);
      expect(topLeft.g, 92);
      expect(topLeft.b, 100);

      final center = patch.at(patch.width ~/ 2, patch.height ~/ 2);
      expect(center.r, 115);
      expect(center.g, 95);
      expect(center.b, 100);
    });
  });

  group('robustModuleColor (referans: gerçek Python robust_module_color)', () {
    RgbImage patchOf(List<Rgb> pixels) => RgbImage(width: pixels.length, height: 1, pixels: pixels);

    test('tek sayıda piksel — sıradan medyan', () {
      final patch = patchOf(const [
        Rgb(100, 100, 100),
        Rgb(110, 90, 105),
        Rgb(95, 105, 98),
      ]);
      final result = robustModuleColor(patch);
      expect(result.r, 100);
      expect(result.g, 100);
      expect(result.b, 100);
    });

    test('çift sayıda piksel — iki ortanca değerin ortalaması', () {
      final patch = patchOf(const [
        Rgb(10, 10, 10),
        Rgb(20, 20, 20),
        Rgb(30, 30, 30),
        Rgb(40, 40, 40),
      ]);
      final result = robustModuleColor(patch);
      expect(result.r, 25);
      expect(result.g, 25);
      expect(result.b, 25);
    });

    test('parlama (glare) ve gölge (shadow) pikselleri elenir', () {
      final patch = patchOf(const [
        Rgb(100, 100, 100),
        Rgb(255, 255, 255), // glare, elenir
        Rgb(2, 2, 2), // shadow, elenir
        Rgb(110, 90, 105),
        Rgb(95, 105, 98),
      ]);
      final result = robustModuleColor(patch);
      expect(result.r, 100);
      expect(result.g, 100);
      expect(result.b, 100);
    });

    test('tüm piksel yaması aykırıysa (hepsi elenirse) yine de tüm yamanın medyanı döner', () {
      final patch = patchOf(const [
        Rgb(255, 255, 255),
        Rgb(252, 253, 254),
        Rgb(251, 250, 255),
      ]);
      final result = robustModuleColor(patch);
      expect(result.r, 252);
      expect(result.g, 253);
      expect(result.b, 255);
    });

    test('özel eşiklerle (glareThreshold=200, shadowThreshold=50) gerçek Python çıktısıyla eşleşir', () {
      final patch = patchOf(const [
        Rgb(100, 100, 100),
        Rgb(255, 255, 255),
        Rgb(2, 2, 2),
        Rgb(110, 90, 105),
        Rgb(95, 105, 98),
      ]);
      final result = robustModuleColor(patch, glareThreshold: 200, shadowThreshold: 50);
      expect(result.r, 100);
      expect(result.g, 100);
      expect(result.b, 100);
    });
  });
}
