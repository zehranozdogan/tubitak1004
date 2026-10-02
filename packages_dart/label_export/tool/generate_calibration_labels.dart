// A/B/C kalibrasyon test etiketlerini üretir — UYGULAMANIN KULLANDIĞI
// DART motoruyla (Python `label_export` ile DEĞİL).
//
// Neden Dart: etiketleri OKUYAN motor (apps/freshqr) Dart. Üreten ile
// okuyanın aynı kod olması şart — iki motor aynı payload için FARKLI QR
// deseni üretiyor (bkz. docs/decisions/0004, "ÜRETİCİ/OKUYUCU UYUMSUZLUĞU").
//
// Neden profil DOSYADAN okunuyor: kalibrasyon yöntemi, tasarım gereği
// sensör profilinin özelliği (etiketin değil). Okuyucu bu yöntemi
// payload'daki `sensor_profile_id` ile paketli profilden alır. Üretici
// başka bir yöntem varsayarsa, basılan yamalar ile okuyucunun uyguladığı
// yöntem ÇELİŞİR — 2 Ekim'de tam olarak bu oldu: B/C etiketleri basıldı
// ama okuyucu üçünü de `white_black` (A) ile okudu, çünkü paketli profil
// öyle diyordu. Bu yüzden burada etiket, uygulamanın okuyacağı profil
// dosyasının ta kendisiyle üretiliyor.
//
// Kullanım (packages_dart/label_export içinden):
//   dart run tool/generate_calibration_labels.dart [çıktı_dizini]
// Varsayılan çıktı: ~/Desktop/QR_Test_Dart

import 'dart:convert';
import 'dart:io';

import 'package:label_export/label_export.dart';

/// Rapor §6.1'deki üç kalibrasyon adayı — her biri kendi profil
/// varyantına işaret eder (bkz. apps/freshqr/assets/reference/).
const _profilIdleri = <String, String>{
  'A': 'GENIPIN_PUTRESIN_v2_A',
  'B': 'GENIPIN_PUTRESIN_v2_B',
  'C': 'GENIPIN_PUTRESIN_v2_C',
};

const _profilDizini = '../../apps/freshqr/assets/reference';

Future<void> main(List<String> args) async {
  final outRoot = Directory(
    args.isNotEmpty ? args.first : '${Platform.environment['HOME']}/Desktop/QR_Test_Dart',
  );
  if (await outRoot.exists()) await outRoot.delete(recursive: true);

  for (final entry in _profilIdleri.entries) {
    final harf = entry.key;
    final profilId = entry.value;

    final profilDosyasi = File('$_profilDizini/$profilId.sensor_profile.json');
    if (!profilDosyasi.existsSync()) {
      stderr.writeln('Profil bulunamadı: ${profilDosyasi.path}');
      exitCode = 1;
      return;
    }
    final profil = jsonDecode(await profilDosyasi.readAsString()) as Map<String, dynamic>;

    final payload = buildLabelPayload(
      productId: 'KALIB-$harf',
      productType: 'levrek',
      productionDate: DateTime.now().toIso8601String().substring(0, 10),
      sensorProfileId: profilId,
      layoutVersion: 'QR_SENSOR_v4',
    );
    final result = await exportLabel(
      payload,
      Directory('${outRoot.path}/$harf'),
      density: 'low',
      sensorProfile: profil,
    );
    final yontem = (profil['calibration_method'] as Map)['code'];
    stdout.writeln('$harf  profil=$profilId  yöntem=$yontem  '
        '-> ${result.paths.length} dosya');
  }
  stdout.writeln('\nYazıldı: ${outRoot.path}');
}
