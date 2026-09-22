// Dağıtılmış reaktif modül seçimi — packages/qr_layout/reactive.py'nin
// Dart portu (rapor §5.2).
//
// MİMARİ SAPMA (bilinçli): Python `random.Random(seed)` (Mersenne
// Twister) kullanıyordu; Dart'ın `dart:math` Random'ı FARKLI bir PRNG
// algoritmasıdır — bu yüzden AYNI seed, İKİ DİLDE FARKLI (ama HER BİRİ
// KENDİ İÇİNDE deterministik/tekrarlanabilir) bir seçim üretir. Bu SORUN
// DEĞİL: `build_layout()` zaten seçilen hücreleri layout_version JSON'una
// SOMUT KOORDİNAT olarak yazıyor — bir Dart TÜKETİCİSİ (analiz/okuma)
// bunları seed'den yeniden TÜRETMEZ, doğrudan JSON'dan okur. Yalnızca bir
// Dart ÜRETİCİSİ (yeni etiket üreten admin ekranı) `selectReactiveModules`'ı
// gerçekten ÇAĞIRIR — o zaman "aynı seed = aynı Dart yerleşimi" yeterlidir,
// Python'un ürettiği GEÇMİŞ yerleşimlerle bit-bit eşleşmesi GEREKMEZ.
//
// Deterministik/rastgelelik-içermeyen kısımlar (chebyshev, boundary
// distance, function distance transform, safety score, seed_from_layout_
// version/crc32) gerçek Python çıktısıyla BİREBİR doğrulandı. RNG'ye bağlı
// seçim fonksiyonları (selectReactiveModules, selectIntentionalErrors) ise
// YAPISAL özellikleriyle (doğru sayı, min_spacing'e uyum, fonksiyon
// modüllerinden kaçınma, aynı seed->aynı sonuç) test edildi — bkz.
// test/reactive_test.dart.

import 'dart:math' as math;

import 'crc32.dart';
import 'function_mask.dart' show matrixSize;

typedef Cell = ({int row, int col});

/// Yoğunluk -> hedef reaktif hücre ORANI (aday havuzunun yüzdesi).
/// Python `DENSITY_FRACTION` ile BİREBİR aynı (bkz. Python dosyasındaki
/// uzun deneysel gerekçe — bu üçü "gerçek Putresin renklerinin düşük
/// kontrastı" yüzünden pratikte medium/high neredeyse aynı davranıyor,
/// dürüst uyarı olarak Python tarafında belgelendi).
const Map<String, double> densityFraction = {'low': 0.02, 'medium': 0.04, 'high': 0.041};
const int minCells = 5;

/// `layoutVersion` metninden DETERMİNİSTİK bir seed türetir — Python'ın
/// `zlib.crc32` ile BİREBİR aynı algoritma (bkz. crc32.dart).
int seedFromLayoutVersion(String layoutVersion) => crc32(layoutVersion);

int _chebyshev(Cell a, Cell b) {
  final dr = (a.row - b.row).abs();
  final dc = (a.col - b.col).abs();
  return dr > dc ? dr : dc;
}

/// Hücrenin QR'ın DIŞ kenarına Chebyshev mesafesi (0 = en kenarda).
int boundaryDistance(Cell cell, int n) {
  final vals = [cell.row, cell.col, n - 1 - cell.row, n - 1 - cell.col];
  return vals.reduce((a, b) => a < b ? a : b);
}

/// Her hücre için EN YAKIN fonksiyon modülüne Chebyshev mesafesi —
/// çok-kaynaklı BFS (8-komşuluk = Chebyshev mesafe).
List<List<int>> functionDistanceTransform(Set<Cell> candidateSet, int n) {
  final dist = List.generate(n, (_) => List.filled(n, -1));
  final queue = <Cell>[];
  var head = 0;
  for (var r = 0; r < n; r++) {
    for (var c = 0; c < n; c++) {
      if (!candidateSet.contains((row: r, col: c))) {
        dist[r][c] = 0;
        queue.add((row: r, col: c));
      }
    }
  }
  while (head < queue.length) {
    final cell = queue[head++];
    final d = dist[cell.row][cell.col] + 1;
    for (var dr = -1; dr <= 1; dr++) {
      for (var dc = -1; dc <= 1; dc++) {
        if (dr == 0 && dc == 0) continue;
        final nr = cell.row + dr, nc = cell.col + dc;
        if (nr >= 0 && nr < n && nc >= 0 && nc < n && dist[nr][nc] == -1) {
          dist[nr][nc] = d;
          queue.add((row: nr, col: nc));
        }
      }
    }
  }
  return dist;
}

/// Bir adayın 'güvenlik' skoru: hem fonksiyon modüllerine HEM de QR'ın dış
/// kenarına olan minimum mesafe.
int safetyScore(Cell cell, List<List<int>> funcDist, int n) {
  final fd = funcDist[cell.row][cell.col];
  final bd = boundaryDistance(cell, n);
  return fd < bd ? fd : bd;
}

int _cellCompare(Cell a, Cell b) {
  if (a.row != b.row) return a.row - b.row;
  return a.col - b.col;
}

/// Aday havuzdan hedef sayıda, mekânsal dağıtılmış VE güvenli bir alt küme
/// seçer (bkz. dosya başlığı — RNG mimari sapması).
List<Cell> selectReactiveModules(
  List<Cell> candidates, {
  String density = 'low',
  int minSpacing = 3,
  int seed = 0,
}) {
  final fraction = densityFraction[density];
  if (fraction == null) {
    throw ArgumentError("density 'low'|'medium'|'high' olmalı, verilen: $density");
  }
  var target = math.max(minCells, (candidates.length * fraction).round());
  target = math.min(target, candidates.length);

  final candidateSet = candidates.toSet();
  final n = candidates.map((c) => math.max(c.row, c.col)).reduce(math.max) + 1;
  final funcDist = functionDistanceTransform(candidateSet, n);

  final rnd = math.Random(seed);
  final decorated = candidates.map((cell) => (cell: cell, tiebreak: rnd.nextDouble())).toList()
    ..sort((a, b) {
      final sa = safetyScore(a.cell, funcDist, n);
      final sb = safetyScore(b.cell, funcDist, n);
      if (sa != sb) return sb - sa; // yüksek->düşük (Python: -safety_score)
      return a.tiebreak.compareTo(b.tiebreak);
    });

  final chosen = <Cell>[];
  for (final entry in decorated) {
    if (chosen.length >= target) break;
    final ok = chosen.every((c) => _chebyshev(entry.cell, c) >= minSpacing);
    if (ok) chosen.add(entry.cell);
  }
  chosen.sort(_cellCompare);
  return chosen;
}

/// Kasıtlı olarak GERÇEK bitinin TERSİYLE render edilecek hücreleri seçer
/// (bkz. dosya başlığı — RNG mimari sapması).
List<Cell> selectIntentionalErrors(
  List<Cell> candidates, {
  required int count,
  Set<Cell>? exclude,
  int minSpacing = 2,
  int seed = 0,
}) {
  final excludeSet = exclude ?? const {};
  final pool = candidates.where((c) => !excludeSet.contains(c)).toList();
  if (count > pool.length) {
    throw ArgumentError('count ($count) dışlananlar sonrası aday havuzundan (${pool.length}) büyük olamaz.');
  }

  final candidateSet = candidates.toSet();
  final n = candidates.map((c) => math.max(c.row, c.col)).reduce(math.max) + 1;
  final funcDist = functionDistanceTransform(candidateSet, n);

  final rnd = math.Random(seed);
  final decorated = pool.map((cell) => (cell: cell, tiebreak: rnd.nextDouble())).toList()
    ..sort((a, b) {
      final sa = safetyScore(a.cell, funcDist, n);
      final sb = safetyScore(b.cell, funcDist, n);
      if (sa != sb) return sb - sa;
      return a.tiebreak.compareTo(b.tiebreak);
    });

  final chosen = <Cell>[];
  for (final entry in decorated) {
    if (chosen.length >= count) break;
    final ok = chosen.every((c) => _chebyshev(entry.cell, c) >= minSpacing);
    if (ok) chosen.add(entry.cell);
  }
  chosen.sort(_cellCompare);
  return chosen;
}

/// layout_version.schema.json'a uyan bir Map üretir —
/// packages/qr_layout/reactive.py::build_layout'ın Dart portu.
///
/// MİMARİ SAPMA: Python `qr` (segno.QRCode) nesnesinden `qr.version`/
/// `qr.error` okuyordu; burada segno YOK, bu yüzden `version`/`eccLevel`
/// doğrudan parametre olarak verilir (gerçek QR encoding'i yapan Dart
/// paketi — henüz seçilmedi — bunları sağlayacak).
Map<String, dynamic> buildLayout({
  required int version,
  required String eccLevel,
  required List<Cell> sensorModules,
  required String layoutVersion,
  String density = 'low',
  Map<String, List<Cell>>? referenceRegions,
  List<Cell>? intentionalErrors,
}) {
  final effectiveRegions = referenceRegions ??
      {
        'black': [(row: 3, col: 3)], // finderBlackModule — colors.dart'a döngüsel bağımlılık kurmamak için sabitlendi
        'white': [(row: 1, col: 1)], // finderWhiteModule
      };
  return {
    'layout_version': layoutVersion,
    'qr_version': version,
    'matrix_size': matrixSize(version),
    'ecc_level': eccLevel.toUpperCase(),
    'module_density': density,
    'sensor_modules': [for (final c in sensorModules) [c.row, c.col]],
    'reference_regions': {
      for (final entry in effectiveRegions.entries)
        entry.key: [for (final c in entry.value) [c.row, c.col]],
    },
    'intentional_errors': [for (final c in (intentionalErrors ?? const <Cell>[])) [c.row, c.col]],
    'decoder_check': {
      'decoders': [],
      'color_states': ['fresh', 'transition', 'spoiled'],
      'decode_success_rate': 0.0,
    },
  };
}
