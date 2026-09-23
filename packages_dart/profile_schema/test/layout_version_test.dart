// layout_version.dart testleri — gerçek
// packages/profile_schema/examples/QR_SENSOR_v4.layout_version.json
// içeriği kullanılır.

import 'package:profile_schema/profile_schema.dart';
import 'package:test/test.dart';

const _validJson = '''
{
  "layout_version": "QR_SENSOR_v4",
  "qr_version": 4,
  "matrix_size": 33,
  "ecc_level": "H",
  "module_density": "low",
  "sensor_modules": [
    [10, 12], [10, 20], [12, 26], [16, 10], [16, 22],
    [20, 16], [22, 28], [26, 12], [26, 22], [28, 18]
  ],
  "reference_regions": {
    "white": [[9, 9], [9, 10]],
    "black": [[24, 23], [24, 24]]
  },
  "intentional_errors": [],
  "decoder_check": {
    "decoders": ["zxing", "quirc"],
    "color_states": ["fresh", "transition", "spoiled"],
    "decode_success_rate": 0.0
  }
}
''';

void main() {
  test('gerçek QR_SENSOR_v4.layout_version.json geçerli', () {
    final layout = parseLayoutVersion(_validJson);
    expect(layout.layoutVersion, 'QR_SENSOR_v4');
    expect(layout.qrVersion, 4);
    expect(layout.matrixSize, 33);
    expect(layout.eccLevel, 'H');
    expect(layout.moduleDensity, 'low');
    expect(layout.sensorModules, hasLength(10));
    expect(layout.sensorModules.first, (10, 12));
    expect(layout.referenceRegions['white'], [(9, 9), (9, 10)]);
    expect(layout.referenceRegions['black'], [(24, 23), (24, 24)]);
    expect(layout.intentionalErrors, isEmpty);
    expect(layout.decoderCheck!.decoders, ['zxing', 'quirc']);
    expect(layout.decoderCheck!.colorStates, ['fresh', 'transition', 'spoiled']);
  });

  test('reference_regions negatif satır kabul eder (kenar yaması, §5.2/5)', () {
    final json = _validJson.replaceFirst('"white": [[9, 9], [9, 10]]', '"white": [[-7, 5]]');
    final layout = parseLayoutVersion(json);
    expect(layout.referenceRegions['white'], [(-7, 5)]);
  });

  test('ecc_level verilmezse varsayılan H', () {
    final json = _validJson.replaceFirst('"ecc_level": "H",', '');
    final layout = parseLayoutVersion(json);
    expect(layout.eccLevel, 'H');
  });

  test('geçersiz ecc_level -> hata', () {
    final json = _validJson.replaceFirst('"ecc_level": "H"', '"ecc_level": "Z"');
    expect(() => parseLayoutVersion(json), throwsA(isA<SchemaValidationException>()));
  });

  test('geçersiz qr_version aralığı -> hata', () {
    final json = _validJson.replaceFirst('"qr_version": 4', '"qr_version": 41');
    expect(() => parseLayoutVersion(json), throwsA(isA<SchemaValidationException>()));
  });

  test('fazladan üst düzey alan -> hata', () {
    final json = _validJson.replaceFirst('"qr_version": 4', '"qr_version": 4, "extra_field": 1');
    expect(() => parseLayoutVersion(json), throwsA(isA<SchemaValidationException>()));
  });

  test('sensor_modules negatif satır/sütun -> hata (Python şeması: minimum:0)', () {
    final json = _validJson.replaceFirst('[10, 12], [10, 20]', '[-1, 12], [10, 20]');
    expect(() => parseLayoutVersion(json), throwsA(isA<SchemaValidationException>()));
  });
}
