// Dosyadan test yolu (scanStoredLabel) ÜÇ kalibrasyon yöntemi için de
// doğru çalışmalı.
//
// 4 Ekim'de bulunan hata: B (white_gray_black) ve C (multicolor_patch)
// etiketleri, yamalar QR'ın dışına taştığı için border=8 ile basılıyor;
// bu yol ise sabit border=4 varsayıyordu. Sonuç: B/C etiketlerinin tüm
// modülleri 4 modül kaymış yerden okunuyordu — sessizce yanlış sonuç.
// analyzeFrame'e eklenen desen-eşleşme kontrolü yakaladı.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:freshqr/data/reference_data.dart';
import 'package:freshqr/services/file_scan.dart';
import 'package:freshqr/services/scan_service.dart';
import 'package:label_export/label_export.dart' as label_export;

void main() {
  late Directory tmp;
  final reference = ReferenceData((p) => File(p).readAsString());

  setUp(() async => tmp = await Directory.systemTemp.createTemp('freshqr_abc_'));
  tearDown(() async {
    try {
      await tmp.delete(recursive: true);
    } catch (_) {}
  });

  for (final (harf, profilId) in const [
    ('A', 'GENIPIN_PUTRESIN_v2_A'),
    ('B', 'GENIPIN_PUTRESIN_v2_B'),
    ('C', 'GENIPIN_PUTRESIN_v2_C'),
  ]) {
    test('$harf ($profilId) dosyadan test edilince gerçek sonuç verir', () async {
      final profile = await reference.sensorProfile(profilId);
      final recipe = await reference.layoutRecipe('QR_SENSOR_v4');
      final payload = label_export.buildLabelPayload(
        productId: 'KALIB-$harf',
        productType: 'levrek',
        productionDate: '2026-10-04',
        sensorProfileId: profilId,
        layoutVersion: 'QR_SENSOR_v4',
      );
      final uretilen = await label_export.exportLabel(
        payload,
        tmp,
        density: recipe.moduleDensity,
        sensorProfile: profile.raw,
      );
      final stem = uretilen.paths['png']!.uri.pathSegments.last.replaceAll('.png', '');

      for (final durum in ['fresh', 'transition', 'spoiled']) {
        final sonuc = await scanStoredLabel(
          dir: tmp,
          stem: stem,
          state: durum,
          reference: reference,
        );
        switch (sonuc) {
          case ScanSuccess(:final result):
            expect(
              result.rescanRecommended,
              isFalse,
              reason: '$harf/$durum reddedildi: ${result.notes.join("; ")}',
            );
            expect(result.technicalLevel, isNotNull, reason: '$harf/$durum seviye üretmedi');
          case ScanInvalidQr(:final reason):
            fail('$harf/$durum geçersiz sayıldı: $reason');
        }
      }
    });
  }
}
