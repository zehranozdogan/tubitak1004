// Sınıf-farkındalıklı okuma (sensorModuleBits) — bkz. pipeline.dart sapma #5.
//
// Senaryo: hücreler iki tonda basılı (bit=1 koyu, bit=0 açık) — gerçek
// etiketteki durum. Ton değerleri STATE_COLORS'tan (taze: açık 214,205,196 /
// koyu 193,176,160; bozuk koyu 54,50,58).

import 'package:color_engine/color_engine.dart';
import 'package:profile_schema/profile_schema.dart' as schema;
import 'package:qr_layout/qr_layout.dart' show finderBlackModule, finderPatternCornerPositions, finderWhiteModule;
import 'package:test/test.dart';

const _scale = 10;
const _border = 4;
const _matrixSize = 21;

RgbImage _photo(Map<({int row, int col}), Rgb> modules) {
  final size = canonicalSize(_matrixSize, scale: _scale, border: _border);
  final pixels = List<Rgb>.filled(size * size, const Rgb(128, 128, 128));
  for (final e in modules.entries) {
    final c = modulePixelCenter(e.key.row, e.key.col, scale: _scale, border: _border);
    for (var dy = -5; dy < 5; dy++) {
      for (var dx = -5; dx < 5; dx++) {
        final x = c.x + dx, y = c.y + dy;
        if (x >= 0 && x < size && y >= 0 && y < size) pixels[y * size + x] = e.value;
      }
    }
  }
  return RgbImage(width: size, height: size, pixels: pixels);
}

const _freshLight = Rgb(214, 205, 196);
const _freshDark = Rgb(193, 176, 160);
const _spoiledDark = Rgb(54, 50, 58);

schema.ScalePointEntry _pt(double v, Rgb c, String state) {
  final l = rgbToLab(c);
  return schema.ScalePointEntry(value: v, lab: [l.L, l.a, l.b], state: state);
}

void main() {
  // P1 taze-açık, P2 taze-koyu, P3 bozuk-koyu (profildeki sıra: açık, koyu, ...)
  final points = [_pt(0.0, _freshLight, 'fresh'), _pt(1.0, _freshDark, 'fresh'), _pt(2.0, _spoiledDark, 'spoiled')];
  final profile = schema.SensorProfile(
    profileId: 'T',
    analyteAxis: 'a',
    scalePoints: points,
    calibrationMethod: const schema.CalibrationMethod(code: 'white_black'),
    classThresholds: const schema.ClassThresholds(),
    outputFields: const [],
  );

  const cells = [
    (row: 10, col: 10),
    (row: 10, col: 12),
    (row: 12, col: 10),
    (row: 12, col: 12),
    (row: 8, col: 8),
  ];
  schema.LayoutVersionData layout() => schema.LayoutVersionData(
        layoutVersion: 'T',
        qrVersion: 1,
        matrixSize: _matrixSize,
        sensorModules: [for (final c in cells) (c.row, c.col)],
        referenceRegions: const {},
      );

  Map<({int row, int col}), Rgb> paint(List<int> bits, {Rgb dark = _freshDark, Rgb light = _freshLight}) => {
        finderWhiteModule: const Rgb(255, 255, 255),
        finderBlackModule: const Rgb(0, 0, 0),
        for (final corner in finderPatternCornerPositions(_matrixSize).values) corner['white']!: const Rgb(255, 255, 255),
        for (var i = 0; i < cells.length; i++) cells[i]: bits[i] == 1 ? dark : light,
      };

  ColorEngineResult run(List<int> bits, {bool withBits = true, Rgb dark = _freshDark, Rgb light = _freshLight}) => analyzeFrame(
        _photo(paint(bits, dark: dark, light: light)),
        sensorProfile: profile,
        layoutVersion: layout(),
        qrCorners: canonicalQrCorners(_matrixSize, scale: _scale, border: _border),
        sensorModuleBits: withBits ? bits : null,
      );

  test('KÖK SORUN: bitsiz eski davranışta çoğunluk sınıfı sonucu değiştirir (açık çoğunlukta P1, koyu çoğunlukta P2)', () {
    expect(run([1, 1, 0, 0, 0], withBits: false).matchedProfilePoint, 0.0); // açık çoğunluk -> açık nokta
    expect(run([1, 1, 1, 0, 0], withBits: false).matchedProfilePoint, 1.0); // koyu çoğunluk -> koyu nokta
  });

  test('sınıf-farkındalıklı: çoğunluk ne olursa olsun AYNI (koyu sınıf) noktaya eşleşir', () {
    for (final bits in [
      [1, 1, 0, 0, 0],
      [1, 1, 1, 0, 0],
      [1, 0, 0, 0, 0],
      [1, 1, 1, 1, 0],
    ]) {
      final r = run(bits);
      expect(r.matchedProfilePoint, 1.0, reason: 'bits=$bits');
      expect(r.freshnessClass, 'fresh');
      expect(r.deltaE, closeTo(0.0, 0.5));
    }
  });

  test('güven: iki ton da kendi sınıfı içinde tutarlıysa 1.0 (bitsiz eski hesapta bu düşük kalabilir)', () {
    final withBits = run([1, 1, 0, 0, 0]);
    expect(withBits.confidence, closeTo(1.0, 1e-6));
    // Uzak iki ton (geçiş benzeri): bitsiz güven düşer, bitli 1.0 kalır.
    const farLight = Rgb(150, 128, 112);
    const farDark = Rgb(110, 92, 84);
    final legacy = run([1, 1, 0, 0, 0], withBits: false, dark: farDark, light: farLight);
    final aware = run([1, 1, 0, 0, 0], dark: farDark, light: farLight);
    expect(legacy.confidence!, lessThan(0.95));
    expect(aware.confidence, closeTo(1.0, 1e-6));
  });

  test('sınıf İÇİ gerçek dağınıklık hâlâ güveni düşürür', () {
    // Koyu sınıfta bir hücre belirgin farklı renkte.
    final bits = [1, 1, 1, 0, 0];
    final modules = paint(bits);
    modules[cells[2]] = const Rgb(120, 60, 60);
    final r = analyzeFrame(
      _photo(modules),
      sensorProfile: profile,
      layoutVersion: layout(),
      qrCorners: canonicalQrCorners(_matrixSize, scale: _scale, border: _border),
      sensorModuleBits: bits,
    );
    expect(r.confidence!, lessThan(1.0));
  });

  test('hiç koyu hücre yoksa açık sınıfa düşer', () {
    final r = run([0, 0, 0, 0, 0]);
    expect(r.matchedProfilePoint, 0.0);
    expect(r.rescanRecommended, isFalse);
  });

  test('iki sınıf uzak profil noktalarına eşleşirse tutarsızlık notu eklenir', () {
    // Koyu sınıf bozuk-koyu (P3), açık sınıf taze-açık (P1): indeks farkı 2.
    final r = run([1, 1, 0, 0, 0], dark: _spoiledDark, light: _freshLight);
    expect(r.notes.any((n) => n.contains('tutarsız olabilir')), isTrue);
  });

  test('komşu noktalar (P1/P2) tutarsızlık notu ÜRETMEZ', () {
    expect(run([1, 1, 0, 0, 0]).notes, isEmpty);
  });

  test('bits uzunluğu sensor_modules ile uyuşmazsa ArgumentError', () {
    expect(
      () => analyzeFrame(
        _photo(paint([1, 1, 0, 0, 0])),
        sensorProfile: profile,
        layoutVersion: layout(),
        qrCorners: canonicalQrCorners(_matrixSize, scale: _scale, border: _border),
        sensorModuleBits: [1, 0],
      ),
      throwsArgumentError,
    );
  });
}
