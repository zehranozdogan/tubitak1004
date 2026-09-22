// QR finder pattern sabitleri — packages/qr_layout/colors.py'nin
// pipeline.dart tarafından ihtiyaç duyulan KÜÇÜK bir alt kümesi (tam
// qr_layout portu ayrı bir iş, bkz. paket README'si).

/// Sol-üst finder pattern'in her QR versiyonunda GARANTİ siyah/beyaz olan
/// iki modülü (ISO/IEC 18004, versiyon bağımsız).
const ({int row, int col}) finderBlackModule = (row: 3, col: 3);
const ({int row, int col}) finderWhiteModule = (row: 1, col: 1);

/// Üç finder pattern köşesinin her birinde siyah/beyaz modül (satır,
/// sütun) konumları: 'top_left', 'top_right', 'bottom_left' (sağ-alt
/// köşede finder YOKTUR — QR'ın kendi tasarımı).
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

/// Etiket kenarı referans yamalarının gerçek renkleri (rapor §6.1 B/C) —
/// `multicolor_patch` kalibrasyonunda "true" renkler olarak kullanılır.
const Map<String, ({double r, double g, double b})> edgeReferenceColors = {
  'gray': (r: 128, g: 128, b: 128),
  'red': (r: 205, g: 40, b: 40),
  'green': (r: 35, g: 150, b: 70),
  'blue': (r: 35, g: 95, b: 190),
};
