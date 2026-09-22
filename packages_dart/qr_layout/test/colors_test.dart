// colors.dart testleri — REFERANS DEĞERLER gerçek Python
// packages/qr_layout/colors.py çalıştırılarak üretildi, TAHMİN EDİLMEDİ.

import 'package:qr_layout/qr_layout.dart';
import 'package:test/test.dart';

void main() {
  group('moduleColor', () {
    test('sensör olmayan modül -> bit rengine göre saf siyah/beyaz', () {
      expect(moduleColor(1, false, null), (0, 0, 0));
      expect(moduleColor(0, false, null), (255, 255, 255));
    });

    test('sensör modülü, state verilmiş -> STATE_COLORS tonu', () {
      expect(moduleColor(1, true, 'fresh'), (193, 176, 160));
      expect(moduleColor(0, true, 'fresh'), (214, 205, 196));
      expect(moduleColor(0, true, 'spoiled'), (78, 66, 66));
    });

    test('sensör modülü, state null -> nötr gri', () {
      expect(moduleColor(1, true, null), (97, 97, 97));
    });
  });

  test('modulePixelCenter gerçek Python module_pixel_center ile eşleşir', () {
    final c = modulePixelCenter(5, 7, scale: 10, border: 4);
    expect(c.y, 95);
    expect(c.x, 115);
  });

  test('edgeGrayPatchPosition gerçek Python çıktısıyla eşleşir', () {
    final pos = edgeGrayPatchPosition(25, border: 4);
    expect(pos.row, -7);
    expect(pos.col, 12);
  });

  test('edgePatchPositions gerçek Python çıktısıyla eşleşir', () {
    final positions = edgePatchPositions(25, border: 4);
    expect(positions['gray'], (row: -7, col: 5));
    expect(positions['red'], (row: -7, col: 10));
    expect(positions['green'], (row: -7, col: 15));
    expect(positions['blue'], (row: -7, col: 20));
  });

  test('sabitler gerçek Python değerleriyle eşleşir', () {
    expect(edgePatchMargin, 4);
    expect(edgePatchSize, 3);
    expect(grayReferenceRgb, (128, 128, 128));
  });

  test('finderPatternCornerPositions gerçek Python çıktısıyla eşleşir (matrixSize=25)', () {
    final positions = finderPatternCornerPositions(25);
    expect(positions['top_left']!['black'], (row: 3, col: 3));
    expect(positions['top_left']!['white'], (row: 1, col: 1));
    expect(positions['top_right']!['black'], (row: 3, col: 21));
    expect(positions['top_right']!['white'], (row: 1, col: 23));
    expect(positions['bottom_left']!['black'], (row: 21, col: 3));
    expect(positions['bottom_left']!['white'], (row: 23, col: 1));
  });
}
