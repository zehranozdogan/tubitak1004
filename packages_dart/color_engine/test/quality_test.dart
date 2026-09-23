// quality.dart testleri — REFERANS DEĞERLER gerçek Python
// packages/color_engine/quality.py (yani cv2.cvtColor/cv2.Laplacian)
// çalıştırılarak üretildi, TAHMİN EDİLMEDİ.
//
// NOT: Python tarafı BGR sırası kullanıyordu; bu portta TÜM Rgb alanları
// gerçek R/G/B'dir (bkz. quality.dart::toGray mimari notu) — bu yüzden
// Python'ın BGR test üçlüleri burada RGB'ye çevrilerek yazıldı (ör. Python
// BGR=(10,20,30) -> burada Rgb(30,20,10), aynı gerçek rengi temsil eder).

import 'package:color_engine/color_engine.dart';
import 'package:test/test.dart';

void main() {
  group('toGray (referans: gerçek cv2.cvtColor BGR2GRAY çıktısı)', () {
    void check(String name, Rgb rgb, double expectedGray) {
      test(name, () {
        final image = RgbImage(width: 1, height: 1, pixels: [rgb]);
        final gray = toGray(image);
        expect(gray.at(0, 0), closeTo(expectedGray, 0.001));
      });
    }

    check('bgr(10,20,30) -> rgb(30,20,10)', const Rgb(30, 20, 10), 22);
    check('bgr(255,0,0) -> rgb(0,0,255)', const Rgb(0, 0, 255), 29);
    check('bgr(0,255,0) -> rgb(0,255,0)', const Rgb(0, 255, 0), 150);
    check('bgr(0,0,255) -> rgb(255,0,0)', const Rgb(255, 0, 0), 76);
    check('bgr(128,128,128) -> rgb(128,128,128)', const Rgb(128, 128, 128), 128);
    check('bgr(200,150,50) -> rgb(50,150,200)', const Rgb(50, 150, 200), 126);
  });

  group('laplacianVariance / sharpnessScore (referans: gerçek cv2.Laplacian, BORDER_REFLECT_101)', () {
    // 7x7 rastgele gri yama — Python np.random.seed(0) ile üretildi.
    final grayValues = [
      139, 182, 153, 138, 108, 164, 111, //
      227, 245, 97, 201, 134, 144, 236, //
      18, 22, 5, 212, 198, 221, 249, //
      203, 117, 199, 30, 163, 36, 240, //
      133, 105, 67, 197, 116, 144, 4, //
      157, 156, 157, 240, 173, 91, 111, //
      177, 15, 170, 171, 53, 32, 80, //
    ].map((v) => v.toDouble()).toList();
    final gray = GrayImage(width: 7, height: 7, values: grayValues);

    test('varyans gerçek cv2.Laplacian().var() ile eşleşir', () {
      expect(laplacianVariance(gray), closeTo(101939.05789254478, 1e-3));
    });

    test('varyans 300 eşiğinin çok üstünde -> sharpnessScore doygunlaşır (1.0)', () {
      expect(sharpnessScore(gray), 1.0);
    });
  });

  group('brightnessScore (referans: gerçek Python _brightness_score)', () {
    test('karanlık görüntü (mean=9.5)', () {
      final gray = GrayImage(width: 4, height: 1, values: [5, 10, 15, 8]);
      expect(brightnessScore(gray), closeTo(0.23750000000000004, 1e-9));
    });

    test('aşırı parlak görüntü (mean=238.75)', () {
      final gray = GrayImage(width: 4, height: 1, values: [230, 240, 250, 235]);
      expect(brightnessScore(gray), closeTo(0.4642857142857143, 1e-9));
    });

    test('normal aralıkta (40-220) -> 1.0', () {
      final gray = GrayImage(width: 3, height: 1, values: [100, 100, 100]);
      expect(brightnessScore(gray), 1.0);
    });
  });

  group('glareScore (referans: gerçek Python _glare_score)', () {
    test('%80 doygun (%65 toleransın üstünde)', () {
      final gray = GrayImage(
        width: 10,
        height: 1,
        values: [255, 255, 255, 255, 255, 255, 255, 255, 100, 100].map((v) => v.toDouble()).toList(),
      );
      expect(glareScore(gray), closeTo(0.4999999999999999, 1e-9));
    });

    test('%100 doygun -> 0.0', () {
      final gray = GrayImage(width: 5, height: 1, values: List.filled(5, 255.0));
      expect(glareScore(gray), 0.0);
    });

    test('doygunluk yok -> 1.0', () {
      final gray = GrayImage(width: 3, height: 1, values: [50, 60, 70]);
      expect(glareScore(gray), 1.0);
    });
  });

  group('qualityScore + shouldRescan (entegrasyon)', () {
    test('iyi kalite: keskin + doygun değil + normal parlaklık -> 1.0', () {
      // Yüksek kontrastlı (keskin), orta parlaklıkta, doygun olmayan bir
      // desen — üç bileşenin de 1.0 vermesi beklenir.
      final pixels = <Rgb>[];
      for (var i = 0; i < 16; i++) {
        pixels.add(i.isEven ? const Rgb(180, 180, 180) : const Rgb(60, 60, 60));
      }
      final image = RgbImage(width: 4, height: 4, pixels: pixels);
      expect(qualityScore(image), 1.0);
    });

    test('shouldRescan eşik altında true döner', () {
      expect(shouldRescan(0.3, 0.5), isTrue);
      expect(shouldRescan(0.7, 0.5), isFalse);
    });
  });
}
