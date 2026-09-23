// Ölçülen rengi sensor_profile.scale_points ile eşleştirme —
// packages/color_engine/matching.py'nin Dart portu (rapor §6.2 adım 7).
//
// Sonuç ekranı kuralı (§7.2, KRİTİK): `hasClassThresholds` false ise
// (bilimsel eşik yok) `freshnessClass` HER ZAMAN null döner — eşleşen
// scale_point'in kendi `state` alanı dolu olsa bile. Uydurma sınıf yok.

import 'colorspace.dart';
import 'types.dart';

/// sensor_profile.scale_points'teki tek bir nokta — profile_schema portu
/// henüz yapılmadığı için (bkz. paket README'si) şimdilik minimal.
class ScalePoint {
  final double value;
  final Lab lab;
  final String? state;

  const ScalePoint({required this.value, required this.lab, this.state});
}

class MatchResult {
  final double matchedProfilePoint;
  final double deltaE;
  final String? freshnessClass;
  final String technicalLevel;

  const MatchResult({
    required this.matchedProfilePoint,
    required this.deltaE,
    required this.freshnessClass,
    required this.technicalLevel,
  });
}

/// En yakın `scale_point`'i ΔE (CIEDE2000) ile bulur. Eşitlik durumunda
/// İLK (en düşük indeksli) nokta kazanır — numpy.argmin ile aynı
/// sözleşme (elle doğrulandı, bkz. test/matching_test.dart).
MatchResult matchProfilePoint(
  Lab measuredLab, {
  required List<ScalePoint> scalePoints,
  required bool hasClassThresholds,
}) {
  if (scalePoints.isEmpty) {
    throw ArgumentError('sensor_profile.scale_points boş olamaz.');
  }

  var bestIndex = 0;
  var bestDistance = deltaE(measuredLab, scalePoints[0].lab);
  for (var i = 1; i < scalePoints.length; i++) {
    final d = deltaE(measuredLab, scalePoints[i].lab);
    if (d < bestDistance) {
      bestDistance = d;
      bestIndex = i;
    }
  }
  final bestPoint = scalePoints[bestIndex];

  return MatchResult(
    matchedProfilePoint: bestPoint.value,
    deltaE: bestDistance,
    freshnessClass: hasClassThresholds ? bestPoint.state : null,
    technicalLevel: 'Renk seviyesi ${bestIndex + 1} / Profil noktası P${bestIndex + 1}',
  );
}
