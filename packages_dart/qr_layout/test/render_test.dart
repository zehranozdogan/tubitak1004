// render.dart testleri — packages/qr_layout/render.py'nin (tests/synthetic/
// test_render_colors.py) Dart karşılığı.

import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:qr_layout/qr_layout.dart';
import 'package:test/test.dart';

Map<String, dynamic> _sampleLayout(GeneratedQr qr) {
  final candidates = reactiveCandidatesForVersion(qr.version);
  final modules = selectReactiveModules(candidates, density: 'low', seed: 1);
  return buildLayout(
    version: qr.version,
    eccLevel: qr.eccLevel,
    sensorModules: modules,
    layoutVersion: 'TEST',
    density: 'low',
  );
}

void main() {
  test('moduleColor: koyu ton her zaman açık tondan daha az parlak (luma)', () {
    double luma(Rgb3 c) => 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;
    for (final state in const ['fresh', 'transition', 'spoiled', null]) {
      final dark = moduleColor(1, true, state);
      final light = moduleColor(0, true, state);
      expect(luma(dark), lessThan(luma(light)));
      expect(moduleColor(1, false, state), equals((r: 0, g: 0, b: 0)));
      expect(moduleColor(0, false, state), equals((r: 255, g: 255, b: 255)));
    }
  });

  test('renderColoredImage: boyut + ilk reaktif hücrenin merkez pikseli doğru durum tonunda', () {
    final qr = generateQr('payload-colors', error: 'H');
    final layout = _sampleLayout(qr);
    final sensorModules = layout['sensor_modules'] as List;
    expect(sensorModules, isNotEmpty);

    final image = renderColoredImage(qr, layout, state: 'spoiled', scale: 4, border: 2);
    final matrixSize = layout['matrix_size'] as int;
    final expectedSize = (matrixSize + 2 * 2) * 4;
    expect(image.width, equals(expectedSize));
    expect(image.height, equals(expectedSize));

    final first = sensorModules.first as List;
    final r = first[0] as int, c = first[1] as int;
    final x = (c + 2) * 4 + 2;
    final y = (r + 2) * 4 + 2;
    final px = image.getPixel(x, y);
    final spoiled = stateColors['spoiled']!;
    final asRgb = (r: px.r.toInt(), g: px.g.toInt(), b: px.b.toInt());
    expect(asRgb == spoiled.dark || asRgb == spoiled.light, isTrue,
        reason: 'piksel $asRgb, spoiled.dark=${spoiled.dark} ya da spoiled.light=${spoiled.light} olmalıydı');
  });

  test('renderLabelImage (white_gray_black): reference_regions.gray YAZILIR (in-place)', () {
    final qr = generateQr('payload-b', error: 'H');
    final layout = _sampleLayout(qr);
    expect((layout['reference_regions'] as Map).containsKey('gray'), isFalse);

    final profile = {
      'calibration_method': {'code': 'white_gray_black'},
    };
    final plain = renderColoredImage(qr, layout, state: null, scale: 10, border: 4);
    final image = renderLabelImage(qr, layout, profile, state: null, scale: 10, border: 4);

    final refs = layout['reference_regions'] as Map;
    expect(refs.containsKey('gray'), isTrue);
    // Yama için ek kenar boşluğu eklendiği için görüntü A'dan büyük olmalı.
    expect(image.width, greaterThan(plain.width));
  });

  test('renderLabelImage (multicolor_patch): 4 ek renk yazılır, PNG olarak kodlanabilir', () {
    final qr = generateQr('payload-c', error: 'H');
    final layout = _sampleLayout(qr);
    final profile = {
      'calibration_method': {'code': 'multicolor_patch'},
    };
    final image = renderLabelImage(qr, layout, profile, state: 'fresh', scale: 10, border: 4);
    final refs = layout['reference_regions'] as Map;
    for (final name in const ['gray', 'red', 'green', 'blue']) {
      expect(refs.containsKey(name), isTrue, reason: '$name eksik');
    }
    final bytes = img.encodePng(image);
    expect(bytes, isNotEmpty);
  });

  test('syntheticStatesPngBytes: 3 durum da üretilir, hepsi geçerli PNG', () {
    final qr = generateQr('payload-states', error: 'H');
    final layout = _sampleLayout(qr);
    final out = syntheticStatesPngBytes(qr, layout, null);
    expect(out.keys.toSet(), equals({'fresh', 'transition', 'spoiled'}));
    for (final bytes in out.values) {
      final decoded = img.decodePng(Uint8List.fromList(bytes));
      expect(decoded, isNotNull);
    }
  });
}
