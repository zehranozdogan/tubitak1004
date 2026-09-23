// exportLabel() testleri — packages/label_export/export.py::export_label()'ın
// (render DAHİL) Dart portu.

import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:label_export/label_export.dart';
import 'package:test/test.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('export_label_test_');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  payloadFor(String productId) => buildLabelPayload(
        productId: productId,
        productType: 'levrek',
        productionDate: '2026-09-23',
        sensorProfileId: 'GENIPIN_PUTRESIN_v2',
        layoutVersion: 'QR_SENSOR_v4',
      );

  test('dosyaları yazar: payload/layout JSON geçerli, 4 PNG geçerli, aynı reaktif hücreler', () async {
    final payload = payloadFor('TR-EXPORT-1');
    final result = await exportLabel(payload, tmp, density: 'low');

    for (final f in result.paths.values) {
      expect(await f.exists(), isTrue, reason: '${f.path} yazılmadı');
    }

    final payloadJson = jsonDecode(await result.paths['payload_json']!.readAsString());
    expect(payloadJson['product_id'], 'TR-EXPORT-1');

    final layoutJson = jsonDecode(await result.paths['layout_json']!.readAsString());
    expect(layoutJson['reference_regions'].keys.toSet(), {'black', 'white'});
    expect((layoutJson['sensor_modules'] as List).length, result.label.layout.sensorModules.length);

    for (final key in ['png', 'state_fresh', 'state_transition', 'state_spoiled']) {
      final bytes = await result.paths[key]!.readAsBytes();
      expect(img.decodePng(bytes), isNotNull, reason: '$key geçerli PNG değil');
    }
  });

  test('multicolor_patch: dosyaya yazılan layout_version.json ek referans yamalarını içerir', () async {
    final payload = payloadFor('TR-EXPORT-C');
    final sensorProfile = {
      'calibration_method': {'code': 'multicolor_patch'},
    };
    final result = await exportLabel(payload, tmp, density: 'low', sensorProfile: sensorProfile);

    final layoutJson = jsonDecode(await result.paths['layout_json']!.readAsString());
    final refs = (layoutJson['reference_regions'] as Map).keys.toSet();
    expect(refs, {'black', 'white', 'gray', 'red', 'green', 'blue'});
  });

  test('aynı layout_version -> aynı reaktif hücreler (determinizm, §5.2/7)', () async {
    final p1 = payloadFor('TR-A');
    final p2 = payloadFor('TR-B');
    final r1 = await exportLabel(p1, tmp, density: 'low');
    final r2 = await exportLabel(p2, tmp, density: 'low');
    expect(r1.label.layout.sensorModules, equals(r2.label.layout.sensorModules));
  });
}
