// Renk motoru ana akışı — packages/color_engine/pipeline.py'nin Dart
// portu (rapor §6.2).
//
// MİMARİ SAPMALAR (Python'dan KASITLI, bkz. her biri için ayrı not):
//
// 1. `qrCorners` burada ZORUNLU parametre, Python'daki gibi opsiyonel/
//    içeride-decode-eden DEĞİL. Python `decode_qr_image_with_corners`
//    (cv2/pyzbar) kullanıyordu; Flutter'da QR tespiti muhtemelen ML Kit
//    ile yapılacak (bkz. apps/flutter_camera_spike) — bu paketin işi
//    SADECE renk analizi, QR tespiti ayrı bir katman/paket olacak.
//
// 2. BGR/RGB karışıklığı YOK. Python'da `image` BGR sırasındaydı (cv2
//    sözleşmesi) ve `corrected_rgb = corrected[:, :, ::-1]` ile Lab
//    matematiğinden ÖNCE RGB'ye çevriliyordu — bu geçmişte gerçek bir
//    hataya yol açmıştı. Bu Dart portunda TÜM `Rgb`/`RgbImage` HER ZAMAN
//    gerçek RGB'dir (bkz. quality.dart::toGray mimari notu) — bu adım
//    tamamen GEREKSİZ ve YOK.
//
// 3. Kalibrasyon yöntemi seçimi Python'da `calibration.get(code)` ile
//    dinamik bir fonksiyon sözlüğünden yapılıyordu; burada tip-güvenli
//    açık dallanma (if/else) kullanıldı — davranış BİREBİR aynı, sadece
//    Dart'ta daha doğal bir desen.
//
// 4. `SensorProfile`/`LayoutVersionData` artık `package:profile_schema`'dan
//    (23 Eylül'de eklendi) — önceden bu dosyada SADECE pipeline'ın
//    ihtiyaç duyduğu alanları taşıyan minimal, kendi sınıfları vardı;
//    şimdi gerçek, doğrulanmış (JSON şema kurallarını uygulayan) tipler
//    doğrudan kullanılıyor. `layoutVersion.sensorModules`/`referenceRegions`
//    hücre tipi profile_schema'da KONUMSAL kayıt (`(int row, int col)`,
//    `.row`/`.col` YOK, sadece söküm/`.$1`/`.$2`) — bu dosyanın geri
//    kalanı ise İSİMLİ kayıt (`({int row, int col})`) kullanıyor
//    (qr_layout ile tutarlı olsun diye); aradaki dönüşüm
//    `_toNamedCell`'de tek bir yerde yapılıyor.

import 'dart:math' as math;

import 'package:profile_schema/profile_schema.dart' as schema;
import 'package:qr_layout/qr_layout.dart' show edgeReferenceColors, finderBlackModule, finderPatternCornerPositions, finderWhiteModule;

import 'calibration.dart';
import 'colorspace.dart';
import 'homography.dart';
import 'matching.dart';
import 'quality.dart';
import 'roi.dart';
import 'types.dart';

({int row, int col}) _toNamedCell((int, int) cell) => (row: cell.$1, col: cell.$2);

const int _canonicalScale = 10;
const int _canonicalBorder = 4;

const Set<String> _supportedWithoutExtraReferences = {
  'white_black',
  'qr_fixed_regions',
  'algorithmic_white_balance',
};

// confidence formülü için doygunluk/taban noktaları — pipeline.py ile
// BİREBİR aynı (bkz. Python dosya başlığındaki uzun gerekçe: FLOOR 21
// Eylül'de gerçek fotoğraflarla ölçüldü, SATURATING daha eski bir
// sentetik taramadan).
const double _spreadSaturatingDeltaE = 20.0;
const double _spreadFloorDeltaE = 4.0;

// Referans köşe tutarsızlığı notu eşiği — SADECE bilgilendirici, confidence'ı
// SAYISAL etkilemez (bkz. Python dosya başlığı — bir çarpan denenmiş,
// gerçek fotoğraflarla aşırı sert bulunup geri alınmıştı).
const double _cornerCvNoteThreshold = 0.25;

// BGR dönüşümü GEREKMEZ (bkz. dosya başlığı sapma #2) — Python'daki
// _REFERENCE_TRUE_COLORS_BGR'nin tersine, burada doğrudan gerçek RGB.
Map<String, Rgb> _referenceTrueColorsRgb() {
  final map = <String, Rgb>{'white': const Rgb(255, 255, 255), 'black': const Rgb(0, 0, 0)};
  for (final entry in edgeReferenceColors.entries) {
    map[entry.key] = Rgb(entry.value.r.toDouble(), entry.value.g.toDouble(), entry.value.b.toDouble());
  }
  return map;
}

double _channelMean(Rgb c) => (c.r + c.g + c.b) / 3.0;

/// QR'ın üç finder pattern köşesindeki BEYAZ referansı ayrı ayrı örnekleyip
/// değişim katsayısını (cv) döner — bkz. dosya başlığı ve Python
/// `_reference_corner_consistency` docstring'i (SADECE bilgilendirici).
double _referenceCornerConsistency(RgbImage canonical, int matrixSize) {
  final positions = finderPatternCornerPositions(matrixSize);
  final whites = <double>[];
  for (final corner in positions.values) {
    final pos = corner['white']!;
    final patch = sampleModuleRoi(canonical, pos.row, pos.col, scale: _canonicalScale, border: _canonicalBorder);
    whites.add(_channelMean(robustModuleColor(patch)));
  }
  final mean = whites.reduce((a, b) => a + b) / whites.length;
  if (mean <= 1e-6) return 0.0;
  var sumSq = 0.0;
  for (final w in whites) {
    sumSq += (w - mean) * (w - mean);
  }
  final variance = sumSq / whites.length;
  return math.sqrt(variance) / mean;
}

double _moduleReadingConfidence(List<ModuleReading> moduleReadings, Lab representativeLab) {
  if (moduleReadings.isEmpty) return 0.0;
  var sum = 0.0;
  for (final m in moduleReadings) {
    sum += deltaE(m.lab, representativeLab);
  }
  final meanSpread = sum / moduleReadings.length;
  final span = _spreadSaturatingDeltaE - _spreadFloorDeltaE;
  final value = 1.0 - (meanSpread - _spreadFloorDeltaE) / span;
  return value < 0.0 ? 0.0 : (value > 1.0 ? 1.0 : value);
}

ColorEngineResult _rescanResult(double quality, String note) {
  return ColorEngineResult(qualityScore: quality, rescanRecommended: true, notes: [note]);
}

/// Tek bir kareden tazelik/teknik sonucu üretir (rapor §6.2 adım 1-8, adım
/// 1 -QR tespiti- hariç — bkz. dosya başlığı sapma #1: `qrCorners` zaten
/// bulunmuş olarak verilir).
ColorEngineResult analyzeFrame(
  RgbImage image, {
  required schema.SensorProfile sensorProfile,
  required schema.LayoutVersionData layoutVersion,
  required List<List<double>> qrCorners,
}) {
  // profile_schema'nın (tam, doğrulanmış) tiplerinden bu fonksiyonun
  // ihtiyaç duyduğu değerleri türet (bkz. dosya başlığı sapma #4).
  final minQualityScore = sensorProfile.qualityGate.minQualityScore;
  final hasClassThresholds = sensorProfile.classThresholds != null;
  final scalePoints = sensorProfile.scalePoints
      .map((e) => ScalePoint(value: e.value, lab: Lab(e.lab[0], e.lab[1], e.lab[2]), state: e.state))
      .toList();
  final sensorModulesCells = layoutVersion.sensorModules.map(_toNamedCell).toList();
  final referenceRegionsCells = {
    for (final entry in layoutVersion.referenceRegions.entries)
      if (entry.value.isNotEmpty) entry.key: _toNamedCell(entry.value.first),
  };

  // 8 (önce kontrol edilir — kötü görüntüde diğer adımlara hiç girilmez, §7.1).
  final quality = qualityScore(image);
  if (shouldRescan(quality, minQualityScore)) {
    return _rescanResult(quality, 'Görüntü kalitesi yetersiz (bulanık/parlamalı/karanlık).');
  }

  if (sensorModulesCells.isEmpty) {
    return _rescanResult(quality, 'layout_version.sensor_modules boş; ölçülecek reaktif hücre yok.');
  }

  // 2. Homografi -> canonical görüntü.
  final canonical = warpToCanonical(
    image,
    qrCorners,
    matrixSize: layoutVersion.matrixSize,
    scale: _canonicalScale,
    border: _canonicalBorder,
  );

  // 2b. Işık düzensizliği için SADECE bilgilendirici sinyal.
  final cornerCv = _referenceCornerConsistency(canonical, layoutVersion.matrixSize);
  final notes = <String>[];
  if (cornerCv > _cornerCvNoteThreshold) {
    notes.add(
      'Referans köşeleri arasında parlaklık farkı var (ışık düzensiz olabilir, '
      'değişim katsayısı ${cornerCv.toStringAsFixed(2)}); yalnızca bilgi amaçlı, '
      'confidence SAYISAL olarak etkilenmedi.',
    );
  }

  // 3. Kalibrasyon.
  Rgb sampleRef(({int row, int col}) pos) {
    final patch = sampleModuleRoi(canonical, pos.row, pos.col, scale: _canonicalScale, border: _canonicalBorder);
    return robustModuleColor(patch);
  }

  final refRegions = referenceRegionsCells;
  final whitePos = refRegions['white'] ?? finderWhiteModule;
  final blackPos = refRegions['black'] ?? finderBlackModule;
  final whiteRef = sampleRef(whitePos);
  final blackRef = sampleRef(blackPos);

  var code = sensorProfile.calibrationMethod.code;
  final trueColors = _referenceTrueColorsRgb();

  Rgb? grayRef;
  List<Rgb>? multicolorCaptured;
  List<Rgb>? multicolorTrue;

  if (code == 'white_gray_black') {
    if (refRegions.containsKey('gray')) {
      grayRef = sampleRef(refRegions['gray']!);
    } else {
      notes.add(
        "Kalibrasyon yöntemi 'white_gray_black' 'gray' referansı istiyor; "
        "layout_version.reference_regions'ta yok, white_black'e düşüldü.",
      );
      code = 'white_black';
    }
  } else if (code == 'multicolor_patch') {
    final extraNames = refRegions.keys.where((n) => n != 'white' && n != 'black' && trueColors.containsKey(n)).toList();
    if (extraNames.length + 2 >= 4) {
      multicolorCaptured = [whiteRef, blackRef, ...extraNames.map((n) => sampleRef(refRegions[n]!))];
      multicolorTrue = [trueColors['white']!, trueColors['black']!, ...extraNames.map((n) => trueColors[n]!)];
    } else {
      notes.add(
        "Kalibrasyon yöntemi 'multicolor_patch' >=4 referans noktası istiyor "
        "(${2 + extraNames.length} bulundu); layout_version.reference_regions yetersiz, "
        "white_black'e düşüldü.",
      );
      code = 'white_black';
    }
  } else if (!_supportedWithoutExtraReferences.contains(code)) {
    notes.add("Kalibrasyon yöntemi '$code' desteklenmiyor; white_black'e düşüldü.");
    code = 'white_black';
  }

  List<Rgb> correctedPixels;
  switch (code) {
    case 'white_gray_black':
      correctedPixels = whiteGrayBlack(canonical.pixels, white: whiteRef, gray: grayRef!, black: blackRef);
    case 'multicolor_patch':
      final fit = fitMulticolorPatch(captured: multicolorCaptured!, trueColors: multicolorTrue!);
      correctedPixels = applyMulticolorPatch(canonical.pixels, fit);
    case 'algorithmic_white_balance':
      correctedPixels = algorithmicWhiteBalance(canonical.pixels);
    case 'qr_fixed_regions':
      correctedPixels = qrFixedRegions(canonical.pixels, white: whiteRef, black: blackRef);
    default: // white_black
      correctedPixels = whiteBlack(canonical.pixels, white: whiteRef, black: blackRef);
  }
  final corrected = RgbImage(width: canonical.width, height: canonical.height, pixels: correctedPixels);

  // 4-5. Reaktif hücrelerin ROI örneklemesi (parlama/gölge elenmiş median).
  final moduleReadings = <ModuleReading>[];
  final rgbSamples = <Rgb>[];
  for (final (:row, :col) in sensorModulesCells) {
    final patch = sampleModuleRoi(corrected, row, col, scale: _canonicalScale, border: _canonicalBorder);
    final rgb = robustModuleColor(patch);
    rgbSamples.add(rgb);
    final lab = rgbToLab(rgb);
    moduleReadings.add(ModuleReading(module: (row, col), normalizedColor: rgb, lab: lab));
  }

  // 6. Temsilci renk: modüller arası median (RGB, HER KANAL BAĞIMSIZ — bkz.
  //    roi.dart::robustModuleColor notu, np.median(axis=0) ile aynı) + Lab.
  double medianOf(Iterable<double> values) {
    final sorted = values.toList()..sort();
    final n = sorted.length;
    if (n.isOdd) return sorted[n ~/ 2];
    return (sorted[n ~/ 2 - 1] + sorted[n ~/ 2]) / 2.0;
  }

  final representativeRgb = Rgb(
    medianOf(rgbSamples.map((p) => p.r)),
    medianOf(rgbSamples.map((p) => p.g)),
    medianOf(rgbSamples.map((p) => p.b)),
  );
  final representativeLab = rgbToLab(representativeRgb);

  // 7. sensor_profile.scale_points ile eşleştirme (§7.2 sınıf kuralı dahil).
  final match = matchProfilePoint(
    representativeLab,
    scalePoints: scalePoints,
    hasClassThresholds: hasClassThresholds,
  );

  return ColorEngineResult(
    qualityScore: quality,
    rescanRecommended: false,
    normalizedColor: representativeRgb,
    lab: representativeLab,
    deltaE: match.deltaE,
    matchedProfilePoint: match.matchedProfilePoint,
    freshnessClass: match.freshnessClass,
    technicalLevel: match.technicalLevel,
    confidence: _moduleReadingConfidence(moduleReadings, representativeLab),
    moduleReadings: moduleReadings,
    notes: notes,
  );
}
