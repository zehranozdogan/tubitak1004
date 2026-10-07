// Dosyadan test yolu (scanStoredLabel) ÜÇ kalibrasyon yöntemi için de
// doğru çalışmalı.
//
// 4 Ekim'de bulunan hata: B (white_gray_black) ve C (multicolor_patch)
// etiketleri, yamalar QR'ın dışına taştığı için border=8 ile basılıyor;
// bu yol ise sabit border=4 varsayıyordu. Sonuç: B/C etiketlerinin tüm
// modülleri 4 modül kaymış yerden okunuyordu — sessizce yanlış sonuç.
// analyzeFrame'e eklenen desen-eşleşme kontrolü yakaladı.

import 'dart:io';

import 'package:flutter/foundation.dart' show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart' show TargetPlatform;
import 'package:flutter_test/flutter_test.dart';
import 'package:freshqr/data/reference_data.dart';
import 'package:freshqr/services/file_scan.dart';
import 'package:freshqr/services/scan_service.dart';
import 'package:label_export/label_export.dart' as label_export;

void main() {
  // scanStoredLabel artık GERÇEK kod çözme yolunu kullanıyor (7 Ekim) ve o
  // yol ML Kit'in platform kanalına dokunuyor — testte binding başlatılmalı.
  // Platform Windows'a sabitleniyor ki ML Kit (bu ortamda arkası yok)
  // denenmesin, zxing2 yolu çalışsın (static_image_scan_test ile aynı desen).
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;
  final reference = ReferenceData((p) => File(p).readAsString());

  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tmp = await Directory.systemTemp.createTemp('freshqr_abc_');
  });
  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
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
          case ScanSuccess(:final result, :final labelInfo):
            expect(
              result.rescanRecommended,
              isFalse,
              reason: '$harf/$durum reddedildi: ${result.notes.join("; ")}',
            );
            expect(result.technicalLevel, isNotNull, reason: '$harf/$durum seviye üretmedi');
            // 7 Ekim: bu yol artık QR'ı GERÇEKTEN çözüyor (eskiden metin
            // label_payload.json'dan okunuyor, köşeler varsayılıyordu).
            // Hangi decoder'ın çözdüğü raporlanmalı.
            expect(labelInfo.usedDecoder, isNotNull,
                reason: '$harf/$durum: decoder bilgisi yok — QR çözülmemiş olabilir');
          case ScanInvalidQr(:final reason):
            fail('$harf/$durum geçersiz sayıldı: $reason');
        }
      }
    });
  }
}
