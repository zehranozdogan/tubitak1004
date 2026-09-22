// Tazelik durumuna göre reaktif modül renkleri — packages/qr_layout/
// colors.py'nin Dart portu (rapor §5, §7, §8).
//
// DEĞERLER: gerçek Putresin deney fotoğraflarına dayanan renkler
// (GENIPIN_PUTRESIN_v2 sensor_profile'ından türetildi) — Python
// tarafındaki değerlerle BİREBİR aynı, uydurma/keyfi DEĞİL.

typedef Rgb3 = (int r, int g, int b);

const Map<String, String> stateLabels = {
  'fresh': 'Taze',
  'transition': 'Geçiş',
  'spoiled': 'Bozuk',
};

const Map<String, ({Rgb3 light, Rgb3 dark})> stateColors = {
  'fresh': (light: (214, 205, 196), dark: (193, 176, 160)), // 0.03125 / 0.0625 mM
  'transition': (light: (150, 128, 112), dark: (110, 92, 84)), // 0.125 / 0.25 mM
  'spoiled': (light: (78, 66, 66), dark: (54, 50, 58)), // 0.5 / 1.0 mM
};

/// Henüz bir duruma atanmamış / yalnızca yerleşimi göstermek için nötr gri.
const ({Rgb3 dark, Rgb3 light}) neutralTones = (dark: (97, 97, 97), light: (224, 224, 224));

/// Tek bir modülün rengini döndürür.
///
/// [bit]: modülün orijinal QR biti (1=koyu, 0=açık)
/// [isSensor]: bu modül reaktif sensör hücresi mi
/// [state]: "fresh" | "transition" | "spoiled" | null (null -> nötr gri)
Rgb3 moduleColor(int bit, bool isSensor, String? state) {
  if (!isSensor) {
    return bit != 0 ? (0, 0, 0) : (255, 255, 255);
  }
  final tones = (state != null ? stateColors[state] : null) ?? neutralTones;
  return bit != 0 ? tones.dark : tones.light;
}

/// Bir QR modülünün (satır, sütun) rasterize edilmiş görüntüdeki piksel
/// merkezi. Dönen (y, x) sırası, bir görüntü dizisinde satır/sütun ile
/// eşleşir (bkz. packages_dart/color_engine/lib/src/homography.dart'taki
/// eşdeğer fonksiyon — ŞİMDİLİK İKİ PAKETTE DE VAR, bkz. paket README'si
/// "sıradaki temizlik" notu).
({int y, int x}) modulePixelCenter(int row, int col, {required int scale, required int border}) {
  final x = (col + border) * scale + scale ~/ 2;
  final y = (row + border) * scale + scale ~/ 2;
  return (y: y, x: x);
}

// Sol-üst finder pattern'in her QR versiyonunda GARANTİ siyah/beyaz olan
// iki modülü (ISO/IEC 18004, versiyon bağımsız).
const ({int row, int col}) finderBlackModule = (row: 3, col: 3);
const ({int row, int col}) finderWhiteModule = (row: 1, col: 1);

Map<String, ({int y, int x})> finderPatternReferencePixels({required int scale, required int border}) {
  return {
    'black': modulePixelCenter(finderBlackModule.row, finderBlackModule.col, scale: scale, border: border),
    'white': modulePixelCenter(finderWhiteModule.row, finderWhiteModule.col, scale: scale, border: border),
  };
}

Map<String, Map<String, ({int row, int col})>> finderPatternCornerPositions(int matrixSize) {
  final last = matrixSize - 1;
  return {
    'top_left': {'black': finderBlackModule, 'white': finderWhiteModule},
    'top_right': {
      'black': (row: finderBlackModule.row, col: last - finderBlackModule.col),
      'white': (row: finderWhiteModule.row, col: last - finderWhiteModule.col),
    },
    'bottom_left': {
      'black': (row: last - finderBlackModule.row, col: finderBlackModule.col),
      'white': (row: last - finderWhiteModule.row, col: finderWhiteModule.col),
    },
  };
}

// --- Etiket kenarı referans yaması (rapor §5.2/5) ---
const Rgb3 grayReferenceRgb = (128, 128, 128);
const int edgePatchMargin = 4;
const int edgePatchSize = 3;

/// Gri yamanın SANAL (satır, sütun) konumu.
({int row, int col}) edgeGrayPatchPosition(int matrixSizeValue, {required int border}) {
  final centerRow = -(border + edgePatchMargin ~/ 2 + 1);
  return (row: centerRow, col: matrixSizeValue ~/ 2);
}

const Map<String, Rgb3> edgeReferenceColors = {
  'gray': grayReferenceRgb,
  'red': (205, 40, 40),
  'green': (35, 150, 70),
  'blue': (35, 95, 190),
};

/// Her adlandırılmış kenar yamasının SANAL (satır, sütun) konumu.
Map<String, ({int row, int col})> edgePatchPositions(
  int matrixSizeValue, {
  required int border,
  Map<String, Rgb3>? colors,
}) {
  final effectiveColors = colors ?? edgeReferenceColors;
  final names = effectiveColors.keys.toList();
  final n = names.length;
  final row = -(border + edgePatchMargin ~/ 2 + 1);
  final step = edgePatchSize + 2;
  final centerCol = matrixSizeValue ~/ 2;
  final startCol = centerCol - (n - 1) * step ~/ 2;
  return {
    for (var i = 0; i < n; i++) names[i]: (row: row, col: startCol + i * step),
  };
}
