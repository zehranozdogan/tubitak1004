// color-engine giriş/çıkış tipleri — packages/color_engine/types.py'nin
// Dart karşılığı (rapor §10.2 ortak sözleşme). Şimdilik sadece Rgb/Lab
// port edildi; ModuleReading/ColorEngineResult pipeline portu sırasında
// eklenecek.

class Rgb {
  final double r;
  final double g;
  final double b;

  const Rgb(this.r, this.g, this.b);

  @override
  String toString() => 'Rgb($r, $g, $b)';
}

class Lab {
  final double L;
  final double a;
  final double b;

  const Lab(this.L, this.a, this.b);

  @override
  String toString() => 'Lab($L, $a, $b)';
}

/// Tek bir reaktif hücrenin normalize edilmiş ölçümü —
/// packages/color_engine/types.py::ModuleReading'in Dart portu.
class ModuleReading {
  final (int row, int col) module;
  final Rgb normalizedColor;
  final Lab lab;

  const ModuleReading({required this.module, required this.normalizedColor, required this.lab});
}

/// color-engine standart çıktısı (rapor §10.2) —
/// packages/color_engine/types.py::ColorEngineResult'ın Dart portu.
///
/// `freshnessClass` null ise: bilimsel eşik yok -> uygulama sınıf
/// göstermez, `technicalLevel` gösterir (rapor §7.2).
class ColorEngineResult {
  final double qualityScore;
  final bool rescanRecommended;
  final Rgb? normalizedColor;
  final Lab? lab;
  final double? deltaE;
  final double? matchedProfilePoint;
  final String? freshnessClass;
  final String? technicalLevel;
  final double? confidence;
  final List<ModuleReading> moduleReadings;
  final List<String> notes;

  const ColorEngineResult({
    required this.qualityScore,
    required this.rescanRecommended,
    this.normalizedColor,
    this.lab,
    this.deltaE,
    this.matchedProfilePoint,
    this.freshnessClass,
    this.technicalLevel,
    this.confidence,
    this.moduleReadings = const [],
    this.notes = const [],
  });
}
