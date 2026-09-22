// pipeline.dart testleri.
//
// Homografi/kalibrasyon/ROI/kalite/eşleştirme HER BİRİ AYRI AYRI gerçek
// Python çıktılarıyla zaten doğrulandı (bkz. diğer test dosyaları) — bu
// dosyanın amacı SADECE analyzeFrame'in ORKESTRASYON mantığını (hangi
// kalibrasyona düşülüyor, hangi notlar ekleniyor, §7.2 kuralı vb.) test
// etmek. `qrCorners` KASITLI olarak canonicalQrCorners ile AYNI verilir
// (kimlik/identity dönüşüm) — böylece test görüntüsü doğrudan "zaten
// canonical" gibi kurulabilir, warpToCanonical (ayrıca doğrulanmış) yine
// GERÇEKTEN çalıştırılır ama sonucu öngörülebilir kalır.

import 'package:color_engine/color_engine.dart';
import 'package:test/test.dart';

const _scale = 10;
const _border = 4;
const _matrixSize = 21;

RgbImage _buildCanonicalLikePhoto({
  required Rgb background,
  required Map<({int row, int col}), Rgb> modules,
}) {
  final size = canonicalSize(_matrixSize, scale: _scale, border: _border);
  final pixels = List<Rgb>.filled(size * size, background);
  void paintModule(int row, int col, Rgb color) {
    final center = modulePixelCenter(row, col, scale: _scale, border: _border);
    for (var dy = -(_scale ~/ 2); dy < _scale ~/ 2; dy++) {
      for (var dx = -(_scale ~/ 2); dx < _scale ~/ 2; dx++) {
        final x = center.x + dx, y = center.y + dy;
        if (x >= 0 && x < size && y >= 0 && y < size) {
          pixels[y * size + x] = color;
        }
      }
    }
  }

  for (final entry in modules.entries) {
    paintModule(entry.key.row, entry.key.col, entry.value);
  }
  return RgbImage(width: size, height: size, pixels: pixels);
}

List<List<double>> _identityCorners() {
  return canonicalQrCorners(_matrixSize, scale: _scale, border: _border);
}

void main() {
  final sensorModules = [
    (row: 10, col: 10),
    (row: 10, col: 12),
    (row: 12, col: 10),
    (row: 12, col: 12),
    (row: 8, col: 8),
  ];

  final freshRgb = const Rgb(193, 176, 160); // STATE_COLORS["fresh"]["dark"]
  final spoiledRgb = const Rgb(54, 50, 58); // STATE_COLORS["spoiled"]["dark"]
  final freshLab = rgbToLab(freshRgb);
  final spoiledLab = rgbToLab(spoiledRgb);

  final scalePoints = [
    ScalePoint(value: 0.0, lab: freshLab, state: 'fresh'),
    ScalePoint(value: 1.0, lab: spoiledLab, state: 'spoiled'),
  ];

  Map<({int row, int col}), Rgb> baseModules(Rgb sensorColor) {
    return {
      finderWhiteModule: const Rgb(255, 255, 255),
      finderBlackModule: const Rgb(0, 0, 0),
      // top_right ve bottom_left finder köşelerinin BEYAZ referansları da
      // (corner-consistency notu tetiklenmesin diye) aynı beyaz.
      for (final corner in finderPatternCornerPositions(_matrixSize).values)
        corner['white']!: const Rgb(255, 255, 255),
      for (final m in sensorModules) m: sensorColor,
    };
  }

  test('kötü kalite (tamamen düz/karanlık görüntü) -> rescan', () {
    final size = canonicalSize(_matrixSize, scale: _scale, border: _border);
    final image = RgbImage.filled(size, size, const Rgb(5, 5, 5));
    final result = analyzeFrame(
      image,
      sensorProfile: SensorProfile(scalePoints: scalePoints, hasClassThresholds: true),
      layoutVersion: LayoutVersion(matrixSize: _matrixSize, sensorModules: sensorModules),
      qrCorners: _identityCorners(),
    );
    expect(result.rescanRecommended, isTrue);
    expect(result.notes.first, contains('kalitesi yetersiz'));
  });

  test('sensor_modules boş -> rescan', () {
    final image = _buildCanonicalLikePhoto(background: const Rgb(128, 128, 128), modules: baseModules(freshRgb));
    final result = analyzeFrame(
      image,
      sensorProfile: SensorProfile(scalePoints: scalePoints, hasClassThresholds: true),
      layoutVersion: LayoutVersion(matrixSize: _matrixSize, sensorModules: const []),
      qrCorners: _identityCorners(),
    );
    expect(result.rescanRecommended, isTrue);
    expect(result.notes.first, contains('sensor_modules boş'));
  });

  test('temiz okuma: white_black kalibrasyonu, doğru sınıf, not YOK, confidence yüksek', () {
    final image = _buildCanonicalLikePhoto(background: const Rgb(128, 128, 128), modules: baseModules(freshRgb));
    final result = analyzeFrame(
      image,
      sensorProfile: SensorProfile(scalePoints: scalePoints, hasClassThresholds: true),
      layoutVersion: LayoutVersion(matrixSize: _matrixSize, sensorModules: sensorModules),
      qrCorners: _identityCorners(),
    );
    expect(result.rescanRecommended, isFalse);
    expect(result.freshnessClass, 'fresh');
    expect(result.notes, isEmpty);
    expect(result.deltaE, closeTo(0.0, 0.5)); // white=255/black=0 -> kalibrasyon kimlik, tam eşleşme beklenir
    expect(result.confidence, greaterThan(0.9)); // tüm sensör hücreleri AYNI renk -> sapma ~0
    expect(result.moduleReadings.length, sensorModules.length);
  });

  test('§7.2 KRİTİK: hasClassThresholds=false -> freshnessClass null (state dolu olsa bile)', () {
    final image = _buildCanonicalLikePhoto(background: const Rgb(128, 128, 128), modules: baseModules(freshRgb));
    final result = analyzeFrame(
      image,
      sensorProfile: SensorProfile(scalePoints: scalePoints, hasClassThresholds: false),
      layoutVersion: LayoutVersion(matrixSize: _matrixSize, sensorModules: sensorModules),
      qrCorners: _identityCorners(),
    );
    expect(result.rescanRecommended, isFalse);
    expect(result.freshnessClass, isNull);
    expect(result.technicalLevel, isNotNull);
  });

  test('spoiled renkte doğru sınıfı bulur (fresh ile karıştırmaz)', () {
    final image = _buildCanonicalLikePhoto(background: const Rgb(128, 128, 128), modules: baseModules(spoiledRgb));
    final result = analyzeFrame(
      image,
      sensorProfile: SensorProfile(scalePoints: scalePoints, hasClassThresholds: true),
      layoutVersion: LayoutVersion(matrixSize: _matrixSize, sensorModules: sensorModules),
      qrCorners: _identityCorners(),
    );
    expect(result.freshnessClass, 'spoiled');
  });

  test("white_gray_black seçili ama 'gray' referansı yok -> white_black'e düşer, not eklenir", () {
    final image = _buildCanonicalLikePhoto(background: const Rgb(128, 128, 128), modules: baseModules(freshRgb));
    final result = analyzeFrame(
      image,
      sensorProfile: SensorProfile(
        scalePoints: scalePoints,
        hasClassThresholds: true,
        calibrationMethodCode: 'white_gray_black',
      ),
      layoutVersion: LayoutVersion(matrixSize: _matrixSize, sensorModules: sensorModules),
      qrCorners: _identityCorners(),
    );
    expect(result.rescanRecommended, isFalse);
    expect(result.notes, isNotEmpty);
    expect(result.notes.first, contains("white_black'e düşüldü"));
    expect(result.freshnessClass, 'fresh'); // yine de doğru sonucu vermeli (fallback çalıştı)
  });

  test('desteklenmeyen kalibrasyon kodu -> white_black\'e düşer, not eklenir', () {
    final image = _buildCanonicalLikePhoto(background: const Rgb(128, 128, 128), modules: baseModules(freshRgb));
    final result = analyzeFrame(
      image,
      sensorProfile: SensorProfile(
        scalePoints: scalePoints,
        hasClassThresholds: true,
        calibrationMethodCode: 'learned',
      ),
      layoutVersion: LayoutVersion(matrixSize: _matrixSize, sensorModules: sensorModules),
      qrCorners: _identityCorners(),
    );
    expect(result.notes.first, contains("desteklenmiyor"));
    expect(result.freshnessClass, 'fresh');
  });

  test('köşe tutarsızlığı notu: bir finder köşesinin beyazı belirgin farklıysa uyarı eklenir', () {
    final modules = baseModules(freshRgb);
    // top_right köşesinin beyazını KOYU yaparak (255->80) belirgin bir
    // tutarsızlık yaratıyoruz (cv eşiği 0.25'i aşacak kadar büyük fark).
    final topRightWhite = finderPatternCornerPositions(_matrixSize)['top_right']!['white']!;
    final modifiedModules = {...modules, topRightWhite: const Rgb(80, 80, 80)};
    final image = _buildCanonicalLikePhoto(background: const Rgb(128, 128, 128), modules: modifiedModules);
    final result = analyzeFrame(
      image,
      sensorProfile: SensorProfile(scalePoints: scalePoints, hasClassThresholds: true),
      layoutVersion: LayoutVersion(matrixSize: _matrixSize, sensorModules: sensorModules),
      qrCorners: _identityCorners(),
    );
    expect(result.notes.any((n) => n.contains('Referans köşeleri')), isTrue);
    // Bilgilendirici NOT dışında hiçbir şeyi etkilememeli (rescan/sınıf değişmemeli).
    expect(result.rescanRecommended, isFalse);
    expect(result.freshnessClass, 'fresh');
  });
}
