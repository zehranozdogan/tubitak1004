// reactive.dart testleri.
//
// Deterministik/rastgelelik-içermeyen kısımlar (chebyshev, boundary
// distance, function distance transform, safety score) gerçek Python
// çıktısıyla BİREBİR doğrulandı (payload "TEST-REACTIVE", version=2,
// n=25, 359 aday — candidates burada `functionMask(2)`'den yeniden
// üretiliyor, zaten ayrı doğrulanmış, bkz. function_mask_test.dart).
//
// RNG'ye bağlı seçim fonksiyonları (bkz. reactive.dart dosya başlığı —
// Dart'ın Random'ı Python'un Mersenne Twister'ından FARKLI, bu KASITLI)
// YAPISAL özellikleriyle test edilir: doğru hücre sayısı, min_spacing'e
// uyum, aynı seed -> aynı sonuç (determinizm).

import 'package:qr_layout/qr_layout.dart';
import 'package:test/test.dart';

List<Cell> _candidatesForVersion(int version) {
  final n = matrixSize(version);
  final mask = functionMask(version);
  final candidates = <Cell>[];
  for (var r = 0; r < n; r++) {
    for (var c = 0; c < n; c++) {
      if (!mask[r][c]) candidates.add((row: r, col: c));
    }
  }
  return candidates;
}

int _chebyshevPublic(Cell a, Cell b) {
  final dr = (a.row - b.row).abs();
  final dc = (a.col - b.col).abs();
  return dr > dc ? dr : dc;
}

void main() {
  group('boundaryDistance (referans: gerçek Python _boundary_distance)', () {
    test('n=21 örnekleri', () {
      expect(boundaryDistance((row: 0, col: 5), 21), 0);
      expect(boundaryDistance((row: 10, col: 10), 21), 10);
      expect(boundaryDistance((row: 20, col: 20), 21), 0);
    });
  });

  group('functionDistanceTransform + safetyScore (referans: gerçek Python, version=2/n=25/359 aday)', () {
    final candidates = _candidatesForVersion(2);

    test('aday sayısı gerçek Python reactive_candidates ile eşleşir', () {
      expect(candidates.length, 359);
    });

    test('mesafe/güvenlik skorları gerçek Python çıktısıyla eşleşir', () {
      final n = matrixSize(2);
      final cset = candidates.toSet();
      final dist = functionDistanceTransform(cset, n);

      expect(dist[10][10], 2);
      expect(safetyScore((row: 10, col: 10), dist, n), 2);

      expect(dist[0][9], 1);
      expect(safetyScore((row: 0, col: 9), dist, n), 0);

      expect(dist[24][24], 4);
      expect(safetyScore((row: 24, col: 24), dist, n), 0);
    });
  });

  group('selectReactiveModules (yapısal doğrulama — bkz. dosya başlığı RNG notu)', () {
    final candidates = _candidatesForVersion(2); // n=25, 359 aday

    test('hedef sayı yaklaşık DENSITY_FRACTION * aday sayısı (en az minCells)', () {
      final selected = selectReactiveModules(candidates, density: 'low', seed: 1);
      // low = %2 * 359 ≈ 7.18 -> round 7, ama minCells=5 tabanı var.
      expect(selected.length, greaterThanOrEqualTo(minCells));
      expect(selected.length, lessThanOrEqualTo(candidates.length));
    });

    test('seçilenler arası Chebyshev mesafesi >= minSpacing', () {
      final selected = selectReactiveModules(candidates, density: 'medium', minSpacing: 3, seed: 2);
      for (var i = 0; i < selected.length; i++) {
        for (var j = i + 1; j < selected.length; j++) {
          expect(_chebyshevPublic(selected[i], selected[j]), greaterThanOrEqualTo(3));
        }
      }
    });

    test('seçilenlerin HİÇBİRİ fonksiyon modülü DEĞİL (hepsi aday havuzunda)', () {
      final selected = selectReactiveModules(candidates, density: 'high', seed: 3);
      final candidateSet = candidates.toSet();
      for (final cell in selected) {
        expect(candidateSet.contains(cell), isTrue, reason: '$cell aday havuzunda değil');
      }
    });

    test('aynı seed -> aynı sonuç (determinizm)', () {
      final a = selectReactiveModules(candidates, density: 'low', seed: 42);
      final b = selectReactiveModules(candidates, density: 'low', seed: 42);
      expect(a, equals(b));
    });

    test('farklı seed -> genelde farklı sonuç (rastgelelik gerçekten etkili)', () {
      final a = selectReactiveModules(candidates, density: 'low', seed: 1);
      final b = selectReactiveModules(candidates, density: 'low', seed: 999);
      expect(a, isNot(equals(b)));
    });

    test('sonuç (satır, sütun) sıralı döner', () {
      final selected = selectReactiveModules(candidates, density: 'low', seed: 7);
      final sorted = [...selected]..sort((a, b) => a.row != b.row ? a.row - b.row : a.col - b.col);
      expect(selected, equals(sorted));
    });

    test('geçersiz density hata fırlatır (Python: ValueError)', () {
      expect(() => selectReactiveModules(candidates, density: 'invalid'), throwsArgumentError);
    });
  });

  group('selectIntentionalErrors (yapısal doğrulama)', () {
    final candidates = _candidatesForVersion(2);

    test('exclude edilenlerle çakışmaz', () {
      final reactive = selectReactiveModules(candidates, density: 'low', seed: 5).toSet();
      final errors = selectIntentionalErrors(candidates, count: 5, exclude: reactive, seed: 6);
      for (final cell in errors) {
        expect(reactive.contains(cell), isFalse);
      }
      expect(errors.length, 5);
    });

    test('havuzdan büyük count hata fırlatır', () {
      expect(
        () => selectIntentionalErrors(candidates, count: candidates.length + 1),
        throwsArgumentError,
      );
    });
  });

  group('buildLayout (referans: gerçek Python build_layout çıktısı)', () {
    test('varsayılan reference_regions + gerçek Python çıktısıyla eşleşir', () {
      final layout = buildLayout(
        version: 2,
        eccLevel: 'h',
        sensorModules: const [(row: 10, col: 10), (row: 10, col: 12), (row: 8, col: 8)],
        layoutVersion: 'QR_TEST_V1',
        density: 'medium',
      );

      expect(layout['layout_version'], 'QR_TEST_V1');
      expect(layout['qr_version'], 2);
      expect(layout['matrix_size'], 25);
      expect(layout['ecc_level'], 'H');
      expect(layout['module_density'], 'medium');
      expect(layout['sensor_modules'], [
        [10, 10],
        [10, 12],
        [8, 8],
      ]);
      expect(layout['reference_regions'], {
        'black': [
          [3, 3],
        ],
        'white': [
          [1, 1],
        ],
      });
      expect(layout['intentional_errors'], <List<int>>[]);
      expect(layout['decoder_check'], {
        'decoders': <String>[],
        'color_states': ['fresh', 'transition', 'spoiled'],
        'decode_success_rate': 0.0,
      });
    });
  });
}
