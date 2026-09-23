// sensor_profile.dart testleri — geçerli/geçersiz durumlar gerçek Python
// `jsonschema` (packages/profile_schema/loader.py::validate) çalıştırılarak
// doğrulandı, TAHMİN EDİLMEDİ.

import 'package:profile_schema/profile_schema.dart';
import 'package:test/test.dart';

const _validJson = '''
{
  "profile_id": "GENIPIN_PUTRESIN_v2",
  "analyte_axis": "putresin_mM",
  "scale_points": [
    { "value": 0.03125, "rgb": [214, 205, 196], "lab": [82.5, 1.5, 6.0], "state": null },
    { "value": 0.0625,  "rgb": [193, 176, 160], "lab": [73.0, 3.5, 11.0], "state": null },
    { "value": 0.125,   "rgb": [150, 128, 112], "lab": [56.0, 6.0, 15.0], "state": null },
    { "value": 0.25,    "rgb": [110, 92, 84],   "lab": [41.0, 7.0, 10.0], "state": null },
    { "value": 0.5,     "rgb": [78, 66, 66],    "lab": [29.5, 5.0, 3.0],  "state": null },
    { "value": 1.0,     "rgb": [54, 50, 58],    "lab": [21.5, 2.0, -4.0], "state": null }
  ],
  "calibration_method": {
    "code": "white_black",
    "params": { "note": "baslangic adayi" }
  },
  "class_thresholds": null,
  "quality_gate": { "min_quality_score": 0.5 },
  "output_fields": ["technical_level", "analyte", "delta_e", "confidence"]
}
''';

void main() {
  test('gerçek GENIPIN_PUTRESIN_v2.sensor_profile.json geçerli', () {
    final profile = parseSensorProfile(_validJson);
    expect(profile.profileId, 'GENIPIN_PUTRESIN_v2');
    expect(profile.analyteAxis, 'putresin_mM');
    expect(profile.scalePoints, hasLength(6));
    expect(profile.scalePoints.first.value, 0.03125);
    expect(profile.scalePoints.first.rgb, [214, 205, 196]);
    expect(profile.scalePoints.first.state, isNull);
    expect(profile.calibrationMethod.code, 'white_black');
    expect(profile.classThresholds, isNull);
    expect(profile.qualityGate.minQualityScore, 0.5);
    expect(profile.outputFields, ['technical_level', 'analyte', 'delta_e', 'confidence']);
  });

  // Her biri gerçek Python'da TEK BİR ihlal olacak şekilde base'den TEK
  // alan değiştirilerek üretildi (bkz. sohbet geçmişi, 23 Eylül).
  const base2Points = '''
  {
    "profile_id": "X", "analyte_axis": "pH",
    "scale_points": [{"value":1,"lab":[1,2,3]}, {"value":2,"lab":[4,5,6]}],
    "calibration_method": {"code": "white_black"}, "output_fields": []
  }
  ''';

  test('geçerli (2 scale_point) taban -> geçerli', () {
    expect(() => parseSensorProfile(base2Points), returnsNormally);
  });

  test('geçersiz profile_id deseni -> hata (gerçek Python: pattern uyumsuzluğu)', () {
    final bad = base2Points.replaceFirst('"profile_id": "X"', '"profile_id": "X!"');
    expect(() => parseSensorProfile(bad), throwsA(isA<SchemaValidationException>()));
  });

  test('geçersiz calibration_method.code -> hata (gerçek Python: enum dışı)', () {
    final bad = base2Points.replaceFirst('"code": "white_black"', '"code": "bogus"');
    expect(() => parseSensorProfile(bad), throwsA(isA<SchemaValidationException>()));
  });

  test('fazladan üst düzey alan -> hata (gerçek Python: additionalProperties)', () {
    final bad = base2Points.replaceFirst('"output_fields": []', '"output_fields": [], "extra_field": 1');
    expect(() => parseSensorProfile(bad), throwsA(isA<SchemaValidationException>()));
  });

  test('min_quality_score aralık dışı -> hata (gerçek Python: maximum aşıldı)', () {
    final bad = base2Points.replaceFirst(
      '"calibration_method"',
      '"quality_gate": {"min_quality_score": 1.5}, "calibration_method"',
    );
    expect(() => parseSensorProfile(bad), throwsA(isA<SchemaValidationException>()));
  });

  test('scale_points.state geçersiz enum -> hata (gerçek Python: enum dışı)', () {
    final bad = base2Points.replaceFirst('{"value":1,"lab":[1,2,3]}', '{"value":1,"lab":[1,2,3],"state":"rotten"}');
    expect(() => parseSensorProfile(bad), throwsA(isA<SchemaValidationException>()));
  });

  test('output_fields geçersiz enum -> hata (gerçek Python: enum dışı)', () {
    final bad = base2Points.replaceFirst('"output_fields": []', '"output_fields": ["not_a_real_field"]');
    expect(() => parseSensorProfile(bad), throwsA(isA<SchemaValidationException>()));
  });

  test('lab yanlış uzunlukta -> hata (gerçek Python: too short)', () {
    final bad = base2Points.replaceFirst('"lab":[1,2,3]', '"lab":[1,2]');
    expect(() => parseSensorProfile(bad), throwsA(isA<SchemaValidationException>()));
  });

  test('scale_points 2\'den az -> hata (minItems)', () {
    final bad = base2Points.replaceFirst(
      '[{"value":1,"lab":[1,2,3]}, {"value":2,"lab":[4,5,6]}]',
      '[{"value":1,"lab":[1,2,3]}]',
    );
    expect(() => parseSensorProfile(bad), throwsA(isA<SchemaValidationException>()));
  });
}
