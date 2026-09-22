// QR fonksiyon (makine-okur) modüllerinin maskesi — ISO/IEC 18004.
// packages/qr_layout/function_mask.py'nin Dart portu.
//
// `functionMask(version)` -> 2B bool matris. True = fonksiyon modülü
// (DOKUNULMAZ, rapor §5.1). False = data/ECC modülü (reaktif hücre adayı).
//
// SAF MATEMATİK — segno (ya da başka bir QR encoding kütüphanesi) GEREKMEZ,
// sadece ISO/IEC 18004'ün yapısal düzenini (finder/timing/alignment/
// format/version bilgisi konumları) hesaplar. Gerçek Python çalıştırılıp
// 4 versiyon (1, 7, 25, 40) için toplam işaretli hücre sayısı + versiyon 1
// için TAM matris + versiyon 7/25 için nokta kontrolleri karşılaştırılarak
// doğrulandı (bkz. test/function_mask_test.dart).

/// Alignment pattern merkez koordinatları (versiyon -> merkez listesi).
/// ISO/IEC 18004 Annex E.
const Map<int, List<int>> alignmentPositions = {
  1: [], 2: [6, 18], 3: [6, 22], 4: [6, 26], 5: [6, 30], 6: [6, 34],
  7: [6, 22, 38], 8: [6, 24, 42], 9: [6, 26, 46], 10: [6, 28, 50],
  11: [6, 30, 54], 12: [6, 32, 58], 13: [6, 34, 62], 14: [6, 26, 46, 66],
  15: [6, 26, 48, 70], 16: [6, 26, 50, 74], 17: [6, 30, 54, 78],
  18: [6, 30, 56, 82], 19: [6, 30, 58, 86], 20: [6, 34, 62, 90],
  21: [6, 28, 50, 72, 94], 22: [6, 26, 50, 74, 98], 23: [6, 30, 54, 78, 102],
  24: [6, 28, 54, 80, 106], 25: [6, 32, 58, 84, 110], 26: [6, 30, 58, 86, 114],
  27: [6, 34, 62, 90, 118], 28: [6, 26, 50, 74, 98, 122],
  29: [6, 30, 54, 78, 102, 126], 30: [6, 26, 52, 78, 104, 130],
  31: [6, 30, 56, 82, 108, 134], 32: [6, 34, 60, 86, 112, 138],
  33: [6, 30, 58, 86, 114, 142], 34: [6, 34, 62, 90, 118, 146],
  35: [6, 30, 54, 78, 102, 126, 150], 36: [6, 24, 50, 76, 102, 128, 154],
  37: [6, 28, 54, 80, 106, 132, 158], 38: [6, 32, 58, 84, 110, 136, 162],
  39: [6, 26, 54, 82, 110, 138, 166], 40: [6, 30, 58, 86, 114, 142, 170],
}; //
// (Python listeleriyle birebir aynı sırayla kopyalandı.)

/// Bir QR versiyonunun kenar uzunluğu (modül).
int matrixSize(int version) {
  if (version < 1 || version > 40) {
    throw ArgumentError('QR versiyonu 1..40 olmalı, verilen: $version');
  }
  return version * 4 + 17;
}

void _fill(List<List<bool>> mask, int r0, int c0, int r1, int c1, int n) {
  for (var r = (r0 < 0 ? 0 : r0); r <= r1 && r < n; r++) {
    for (var c = (c0 < 0 ? 0 : c0); c <= c1 && c < n; c++) {
      mask[r][c] = true;
    }
  }
}

List<List<bool>> functionMask(int version) {
  final n = matrixSize(version);
  final mask = List.generate(n, (_) => List.filled(n, false));

  // --- Finder pattern + separator (8x8 blok, 3 köşe) ---
  _fill(mask, 0, 0, 7, 7, n);
  _fill(mask, 0, n - 8, 7, n - 1, n);
  _fill(mask, n - 8, 0, n - 1, 7, n);

  // --- Timing pattern (satır 6 ve sütun 6) ---
  for (var i = 0; i < n; i++) {
    mask[6][i] = true;
    mask[i][6] = true;
  }

  // --- Dark module ---
  mask[4 * version + 9][8] = true;

  // --- Format bilgisi (rezerve) ---
  _fill(mask, 0, 8, 8, 8, n); // sol-üst dikey şerit
  _fill(mask, 8, 0, 8, 8, n); // sol-üst yatay şerit
  _fill(mask, 8, n - 8, 8, n - 1, n); // sağ-üst yatay şerit
  _fill(mask, n - 7, 8, n - 1, 8, n); // sol-alt dikey şerit

  // --- Version bilgisi (v >= 7, rezerve) ---
  if (version >= 7) {
    _fill(mask, 0, n - 11, 5, n - 9, n); // sağ-üst 6x3
    _fill(mask, n - 11, 0, n - 9, 5, n); // sol-alt 3x6
  }

  // --- Alignment pattern (5x5), finder'larla çakışanlar hariç ---
  final centers = alignmentPositions[version]!;
  if (centers.isNotEmpty) {
    final last = centers.last;
    final skip = {(6, 6), (6, last), (last, 6)};
    for (final r in centers) {
      for (final c in centers) {
        if (skip.contains((r, c))) continue;
        _fill(mask, r - 2, c - 2, r + 2, c + 2, n);
      }
    }
  }

  return mask;
}
