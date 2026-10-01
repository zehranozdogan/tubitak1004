// A/B/C kalibrasyon test etiketlerini üretir — UYGULAMANIN KULLANDIĞI
// DART motoruyla (Python `label_export` ile DEĞİL).
//
// Neden Dart: etiketleri OKUYAN motor (apps/freshqr) Dart. Üreten ile
// okuyanın aynı kod olması, iki motor arasındaki olası bir ayrışmanın
// kalibrasyon testini kirletmesini engeller — özellikle Python ile Dart'ın
// BİLEREK ayrıştığı bir nokta varken (kenar yaması border düzeltmesi
// 28 Eylül'de Dart'a uygulandı, Python'a bilerek uygulanmadı; bkz.
// docs/decisions/0004 son maddeler).
//
// Kullanım (packages_dart/label_export içinden):
//   dart run tool/generate_calibration_labels.dart [çıktı_dizini]
// Varsayılan çıktı: ~/Desktop/QR_Test_Dart
//
// Python karşılığı `tests/device/` altındaki baskı-testi scriptleriydi;
// bu, onun Dart motorunu kullanan eşdeğeri.

import 'dart:io';

import 'package:label_export/label_export.dart';

/// Rapor §6.1'deki üç kalibrasyon adayı. A referans yaması kullanmaz
/// (profil verilmez -> QR-içi beyaz/siyah), B/C kenar yaması bastırır.
const _methods = <String, Map<String, dynamic>?>{
  'A': null,
  'B': {
    'calibration_method': {'code': 'white_gray_black'},
  },
  'C': {
    'calibration_method': {'code': 'multicolor_patch'},
  },
};

Future<void> main(List<String> args) async {
  final outRoot = Directory(
    args.isNotEmpty ? args.first : '${Platform.environment['HOME']}/Desktop/QR_Test_Dart',
  );
  if (await outRoot.exists()) await outRoot.delete(recursive: true);

  for (final entry in _methods.entries) {
    final letter = entry.key;
    final payload = buildLabelPayload(
      productId: 'DART-$letter',
      productType: 'levrek',
      productionDate: DateTime.now().toIso8601String().substring(0, 10),
      sensorProfileId: 'GENIPIN_PUTRESIN_v2',
      layoutVersion: 'QR_SENSOR_v4',
    );
    final result = await exportLabel(
      payload,
      Directory('${outRoot.path}/$letter'),
      density: 'low',
      sensorProfile: entry.value,
    );
    stdout.writeln('$letter -> ${result.paths.length} dosya');
    for (final p in result.paths.entries) {
      stdout.writeln('   ${p.key.padRight(18)} ${p.value.path}');
    }
  }
  stdout.writeln('\nYazıldı: ${outRoot.path}');
}
