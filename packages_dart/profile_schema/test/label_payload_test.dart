// label_payload.dart testleri — gerçek
// packages/profile_schema/examples/TR45678.label_payload.json içeriği.

import 'dart:convert';

import 'package:profile_schema/profile_schema.dart';
import 'package:test/test.dart';

const _validJson = '''
{
  "product_id": "TR45678",
  "product_type": "LEVREK",
  "production_date": "2026-09-10",
  "sensor_profile_id": "GENIPIN_PUTRESIN_v2",
  "layout_version": "QR_SENSOR_v4"
}
''';

void main() {
  test('gerçek TR45678.label_payload.json geçerli', () {
    final payload = parseLabelPayload(_validJson);
    expect(payload.productId, 'TR45678');
    expect(payload.productType, 'LEVREK');
    expect(payload.productionDate, '2026-09-10');
    expect(payload.sensorProfileId, 'GENIPIN_PUTRESIN_v2');
    expect(payload.layoutVersion, 'QR_SENSOR_v4');
    expect(payload.profileUri, isNull);
  });

  test('toJson round-trip', () {
    final payload = parseLabelPayload(_validJson);
    final again = parseLabelPayload(json.encode(payload.toJson()));
    expect(again.productId, payload.productId);
    expect(again.productionDate, payload.productionDate);
  });

  test('eksik zorunlu alan -> hata', () {
    final bad = _validJson.replaceFirst('"product_id": "TR45678",', '');
    expect(() => parseLabelPayload(bad), throwsA(isA<SchemaValidationException>()));
  });

  test('geçersiz tarih formatı -> hata', () {
    final bad = _validJson.replaceFirst('"2026-09-10"', '"10/09/2026"');
    expect(() => parseLabelPayload(bad), throwsA(isA<SchemaValidationException>()));
  });

  test('fazladan alan -> hata', () {
    final bad = _validJson.replaceFirst('"product_id": "TR45678"', '"product_id": "TR45678", "extra_field": 1');
    expect(() => parseLabelPayload(bad), throwsA(isA<SchemaValidationException>()));
  });

  test('opsiyonel profile_uri kabul edilir', () {
    final withUri = _validJson.replaceFirst(
      '"layout_version": "QR_SENSOR_v4"',
      '"layout_version": "QR_SENSOR_v4", "profile_uri": "pkg://profiles/genipin_v2"',
    );
    final payload = parseLabelPayload(withUri);
    expect(payload.profileUri, 'pkg://profiles/genipin_v2');
  });
}
