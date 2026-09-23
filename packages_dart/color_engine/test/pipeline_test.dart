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
//
// 23 Eylül: sensorProfile/layoutVersion artık package:profile_schema'nın
// GERÇEK, doğrulanmış tipleri (bkz. pipeline.dart dosya başlığı sapma #4).

import 'package:color_engine/color_engine.dart';
import 'package:profile_schema/profile_schema.dart' as schema;
import 'package:qr_layout/qr_layout.dart' show finderBlackModule, finderPatternCornerPositions, finderWhiteModule;
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

/// Test yardımcıları: gerçek `profile_schema.SensorProfile`/
/// `LayoutVersionData` inşa eder — bu testlerin odağı olmayan zorunlu
/// alanlara (profileId, analyteAxis, outputFields, qrVersion, layoutVersion
/// metni) makul sabit değerler verilir.
schema.SensorProfile _profile({
  required List<schema.ScalePointEntry> scalePoints,
  required bool hasClassThresholds,
  String calibrationCode = 'white_black',
}) {
  return schema.SensorProfile(
    profileId: 'TEST_PROFILE',
    analyteAxis: 'test_axis',
    scalePoints: scalePoints,
    calibrationMethod: schema.CalibrationMethod(code: calibrationCode),
    classThresholds: hasClassThresholds ? const schema.ClassThresholds() : null,
    outputFields: const [],
  );
}

schema.LayoutVersionData _layout({
  required List<({int row, int col})> sensorModules,
  Map<String, List<(int, int)>> referenceRegions = const {},
}) {
  return schema.LayoutVersionData(
    layoutVersion: 'TEST_LAYOUT',
    qrVersion: 1,
    matrixSize: _matrixSize,
    sensorModules: [for (final m in sensorModules) (m.row, m.col)],
    referenceRegions: referenceRegions,
  );
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
    schema.ScalePointEntry(value: 0.0, lab: [freshLab.L, freshLab.a, freshLab.b], state: 'fresh'),
    schema.ScalePointEntry(value: 1.0, lab: [spoiledLab.L, spoiledLab.a, spoiledLab.b], state: 'spoiled'),
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
      sensorProfile: _profile(scalePoints: scalePoints, hasClassThresholds: true),
      layoutVersion: _layout(sensorModules: sensorModules),
      qrCorners: _identityCorners(),
    );
    expect(result.rescanRecommended, isTrue);
    expect(result.notes.first, contains('kalitesi yetersiz'));
  });

  test('sensor_modules boş -> rescan', () {
    final image = _buildCanonicalLikePhoto(background: const Rgb(128, 128, 128), modules: baseModules(freshRgb));
    final result = analyzeFrame(
      image,
      sensorProfile: _profile(scalePoints: scalePoints, hasClassThresholds: true),
      layoutVersion: _layout(sensorModules: const []),
      qrCorners: _identityCorners(),
    );
    expect(result.rescanRecommended, isTrue);
    expect(result.notes.first, contains('sensor_modules boş'));
  });

  test('temiz okuma: white_black kalibrasyonu, doğru sınıf, not YOK, confidence yüksek', () {
    final image = _buildCanonicalLikePhoto(background: const Rgb(128, 128, 128), modules: baseModules(freshRgb));
    final result = analyzeFrame(
      image,
      sensorProfile: _profile(scalePoints: scalePoints, hasClassThresholds: true),
      layoutVersion: _layout(sensorModules: sensorModules),
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
      sensorProfile: _profile(scalePoints: scalePoints, hasClassThresholds: false),
      layoutVersion: _layout(sensorModules: sensorModules),
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
      sensorProfile: _profile(scalePoints: scalePoints, hasClassThresholds: true),
      layoutVersion: _layout(sensorModules: sensorModules),
      qrCorners: _identityCorners(),
    );
    expect(result.freshnessClass, 'spoiled');
  });

  test("white_gray_black seçili ama 'gray' referansı yok -> white_black'e düşer, not eklenir", () {
    final image = _buildCanonicalLikePhoto(background: const Rgb(128, 128, 128), modules: baseModules(freshRgb));
    final result = analyzeFrame(
      image,
      sensorProfile: _profile(
        scalePoints: scalePoints,
        hasClassThresholds: true,
        calibrationCode: 'white_gray_black',
      ),
      layoutVersion: _layout(sensorModules: sensorModules),
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
      sensorProfile: _profile(
        scalePoints: scalePoints,
        hasClassThresholds: true,
        calibrationCode: 'learned',
      ),
      layoutVersion: _layout(sensorModules: sensorModules),
      qrCorners: _identityCorners(),
    );
    expect(result.notes.first, contains("desteklenmiyor"));
    expect(result.freshnessClass, 'fresh');
  });

  test(
      'multicolor_patch kalibrasyonu: uçtan uca (>=4 referans noktası, '
      'calibration_test.dart\'taki gerçek numpy.linalg.lstsq ile doğrulanmış '
      'sabitlerin AYNISI kullanılarak)', () {
    // Bu testin amacı fitMulticolorPatch/applyMulticolorPatch'in matematiğini
    // TEKRAR doğrulamak DEĞİL (bkz. calibration_test.dart — orada gerçek
    // Python numpy.linalg.lstsq çıktısıyla bit bit doğrulandı); amaç SADECE
    // pipeline.dart'ın layout_version.reference_regions'tan 6 referans
    // noktasını (white/black/gray/red/green/blue) DOĞRU SIRAYLA okuyup
    // fitMulticolorPatch/applyMulticolorPatch'e doğru aktardığını ve
    // sonucun sensör hücrelerine doğru uygulandığını uçtan uca kanıtlamak.
    // captured/trueColors DEĞERLERİ ve beklenen düzeltilmiş piksel
    // calibration_test.dart'la BİREBİR AYNI (kopyalanmadı, oradan alındı).
    const capturedWhite = Rgb(240, 235, 230);
    const capturedBlack = Rgb(10, 12, 15);
    const capturedGray = Rgb(128, 124, 120);
    const capturedRed = Rgb(200, 60, 50);
    const capturedGreen = Rgb(50, 180, 70);
    const capturedBlue = Rgb(60, 70, 190);
    const capturedSensor = Rgb(150, 100, 80);
    // calibration_test.dart 'düzeltilmiş pikseller gerçek Python çıktısıyla
    // eşleşir' testinde AYNI 6 referansla Rgb(150,100,80) -> Rgb(152,89,78).
    const correctedSensorRgb = Rgb(152, 89, 78);

    final refPositions = <String, ({int row, int col})>{
      'white': (row: -2, col: 2),
      'black': (row: -2, col: 5),
      'gray': (row: -2, col: 8),
      'red': (row: -2, col: 11),
      'green': (row: -2, col: 14),
      'blue': (row: -2, col: 17),
    };
    final refColors = <String, Rgb>{
      'white': capturedWhite,
      'black': capturedBlack,
      'gray': capturedGray,
      'red': capturedRed,
      'green': capturedGreen,
      'blue': capturedBlue,
    };

    final modules = {
      ...baseModules(capturedSensor),
      for (final entry in refPositions.entries) entry.value: refColors[entry.key]!,
    };
    final image = _buildCanonicalLikePhoto(background: const Rgb(128, 128, 128), modules: modules);

    final correctedLab = rgbToLab(correctedSensorRgb);
    final scalePointsHere = [
      schema.ScalePointEntry(value: 0.0, lab: [correctedLab.L, correctedLab.a, correctedLab.b], state: 'spoiled'),
      schema.ScalePointEntry(value: 1.0, lab: [freshLab.L, freshLab.a, freshLab.b], state: 'fresh'),
    ];

    final result = analyzeFrame(
      image,
      sensorProfile: _profile(scalePoints: scalePointsHere, hasClassThresholds: true, calibrationCode: 'multicolor_patch'),
      layoutVersion: _layout(
        sensorModules: sensorModules,
        referenceRegions: {for (final e in refPositions.entries) e.key: [(e.value.row, e.value.col)]},
      ),
      qrCorners: _identityCorners(),
    );

    expect(result.rescanRecommended, isFalse);
    expect(result.notes, isEmpty); // yeterli referans var, hiçbir fallback/uyarı tetiklenmemeli
    expect(result.freshnessClass, 'spoiled');
    expect(result.deltaE, closeTo(0.0, 0.5)); // düzeltilmiş sensör rengi scale_point'e TAM denk geliyor
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
      sensorProfile: _profile(scalePoints: scalePoints, hasClassThresholds: true),
      layoutVersion: _layout(sensorModules: sensorModules),
      qrCorners: _identityCorners(),
    );
    expect(result.notes.any((n) => n.contains('Referans köşeleri')), isTrue);
    // Bilgilendirici NOT dışında hiçbir şeyi etkilememeli (rescan/sınıf değişmemeli).
    expect(result.rescanRecommended, isFalse);
    expect(result.freshnessClass, 'fresh');
  });
}
