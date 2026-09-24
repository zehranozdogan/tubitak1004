// resolveLabelLayout: okuyucunun layout'u admin ile AYNI türetmesi.

import 'dart:io';

import 'package:label_export/label_export.dart';
import 'package:test/test.dart';

void main() {
  final payload = buildLabelPayload(
    productId: 'TR45678',
    productType: 'levrek',
    productionDate: '2026-09-23',
    sensorProfileId: 'GENIPIN_PUTRESIN_v2',
    layoutVersion: 'QR_SENSOR_v4',
  );

  test('white_black: admin export ile AYNI sensor_modules ve reference_regions', () async {
    final tmp = await Directory.systemTemp.createTemp('resolve_layout_');
    try {
      final profile = {
        'calibration_method': {'code': 'white_black'},
      };
      final exported = await exportLabel(payload, tmp, density: 'low', sensorProfile: profile);
      final resolved = resolveLabelLayout(payload, density: 'low', sensorProfile: profile);
      expect(resolved.layoutJson['sensor_modules'], exported.label.layoutJson['sensor_modules']);
      expect(resolved.layoutJson['reference_regions'], exported.label.layoutJson['reference_regions']);
      expect(resolved.layout.matrixSize, exported.label.layout.matrixSize);
    } finally {
      try {
        await tmp.delete(recursive: true);
      } catch (_) {}
    }
  });

  test('multicolor_patch: kenar referans yamaları reference_regions\'a yazılır', () {
    final resolved = resolveLabelLayout(
      payload,
      sensorProfile: {
        'calibration_method': {'code': 'multicolor_patch'},
      },
    );
    final refs = resolved.layout.referenceRegions.keys.toSet();
    expect(refs, containsAll(['white', 'black', 'gray', 'red', 'green', 'blue']));
  });
}
