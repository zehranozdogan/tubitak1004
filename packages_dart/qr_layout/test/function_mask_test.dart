// function_mask.dart testleri — REFERANS DEĞERLER gerçek Python
// packages/qr_layout/function_mask.py çalıştırılarak üretildi, TAHMİN
// EDİLMEDİ.

import 'package:qr_layout/qr_layout.dart';
import 'package:test/test.dart';

void main() {
  group('matrixSize', () {
    test('gerçek Python matrix_size ile eşleşir', () {
      expect(matrixSize(1), 21);
      expect(matrixSize(7), 45);
      expect(matrixSize(25), 117);
      expect(matrixSize(40), 177);
    });

    test('1..40 dışı hata fırlatır', () {
      expect(() => matrixSize(0), throwsArgumentError);
      expect(() => matrixSize(41), throwsArgumentError);
    });
  });

  group('functionMask', () {
    test('işaretli hücre sayısı gerçek Python çıktısıyla eşleşir (4 versiyon)', () {
      int trueCount(List<List<bool>> mask) => mask.fold(0, (sum, row) => sum + row.where((v) => v).length);

      expect(trueCount(functionMask(1)), 233);
      expect(trueCount(functionMask(7)), 457);
      expect(trueCount(functionMask(25)), 981);
      expect(trueCount(functionMask(40)), 1681);
    });

    test('versiyon 1 TAM matris gerçek Python çıktısıyla piksel piksel eşleşir', () {
      const rows = [
        '111111111000011111111',
        '111111111000011111111',
        '111111111000011111111',
        '111111111000011111111',
        '111111111000011111111',
        '111111111000011111111',
        '111111111111111111111',
        '111111111000011111111',
        '111111111000011111111',
        '000000100000000000000',
        '000000100000000000000',
        '000000100000000000000',
        '000000100000000000000',
        '111111111000000000000',
        '111111111000000000000',
        '111111111000000000000',
        '111111111000000000000',
        '111111111000000000000',
        '111111111000000000000',
        '111111111000000000000',
        '111111111000000000000',
      ];
      final mask = functionMask(1);
      expect(mask.length, 21);
      for (var r = 0; r < 21; r++) {
        for (var c = 0; c < 21; c++) {
          final expected = rows[r][c] == '1';
          expect(mask[r][c], expected, reason: 'mask[$r][$c]');
        }
      }
    });

    test('versiyon 7 nokta kontrolleri (version bilgisi bloğu dahil)', () {
      final mask = functionMask(7);
      expect(mask[0][0], isTrue); // finder
      expect(mask[6][6], isTrue); // timing/finder kesişimi
      expect(mask[0][36], isTrue); // sağ-üst version bilgisi
      expect(mask[34][0], isTrue); // sol-alt version bilgisi
      expect(mask[4 * 7 + 9][8], isTrue); // dark module
      expect(mask[22][22], isTrue); // alignment pattern merkezi
    });

    test('versiyon 25 alignment pattern merkezleri işaretli', () {
      final mask = functionMask(25);
      expect(alignmentPositions[25], [6, 32, 58, 84, 110]);
      for (final (r, c) in [(32, 32), (32, 58), (58, 32), (6, 32), (32, 6)]) {
        expect(mask[r][c], isTrue, reason: '($r,$c)');
      }
    });
  });
}
