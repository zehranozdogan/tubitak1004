// Küçük, dış bağımlılıksız lineer cebir yardımcıları — calibration.dart
// (multicolor_patch, en küçük kareler) ve homography.dart (perspektif
// dönüşüm çözümü + 3x3 tersi) tarafından paylaşılır.

/// A x = B çöz (A: NxN, B: NxM) — Gauss-Jordan, kısmi pivotlama.
List<List<double>> solveLinearSystem(List<List<double>> a, List<List<double>> b) {
  final n = a.length;
  final m = b[0].length;
  final aug = List.generate(n, (i) => [...a[i], ...b[i]]);

  for (var col = 0; col < n; col++) {
    var pivotRow = col;
    var maxAbs = aug[col][col].abs();
    for (var r = col + 1; r < n; r++) {
      if (aug[r][col].abs() > maxAbs) {
        maxAbs = aug[r][col].abs();
        pivotRow = r;
      }
    }
    if (pivotRow != col) {
      final tmp = aug[col];
      aug[col] = aug[pivotRow];
      aug[pivotRow] = tmp;
    }
    final pivot = aug[col][col];
    for (var j = 0; j < n + m; j++) {
      aug[col][j] /= pivot;
    }
    for (var r = 0; r < n; r++) {
      if (r == col) continue;
      final factor = aug[r][col];
      if (factor == 0) continue;
      for (var j = 0; j < n + m; j++) {
        aug[r][j] -= factor * aug[col][j];
      }
    }
  }

  return List.generate(n, (i) => aug[i].sublist(n, n + m));
}

/// NxN kimlik matrisi.
List<List<double>> identityMatrix(int n) {
  return List.generate(n, (i) => List.generate(n, (j) => i == j ? 1.0 : 0.0));
}
