// KALİTE KAPISI — bulanıklık altında sessiz yanlış sonuç vermemeli.
//
// 4 Ekim'de ölçüldü: eşik 0.5 iken kapı PRATİKTE HİÇ tetiklenmiyordu.
// Bulanıklık artarken okuma kalitesi en düşük ~0.68'e iniyor, ondan
// sonra QR hiç çözülmüyor ("Geçersiz QR"). Yani 0.5'lik eşiğe hiç
// ulaşılmıyordu — ve 0.68-0.72 aralığında uygulama KENDİNDEN EMİN YANLIŞ
// cevap veriyordu (gerçek P4 iken P2 diyebiliyordu: iki seviye sapma).
//
// 9 etiket x 10 bulanıklık seviyesi (90 örnek) taranınca yanlışların
// TAMAMI 0.72 ve altında çıktı; 0.73 ve üstünde tek yanlış yok. Eşik
// bu yüzden 0.75'e çekildi (küçük güvenlik payıyla). Gerçek telefon
// okumaları 0.98-1.00 verdiği için sahada iyi okumalar elenmiyor.
//
// Bu test o kuralı korur: kabul edilen her sonuç DOĞRU olmalı.

import 'dart:io';

import 'package:flutter/foundation.dart' show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart' show TargetPlatform;
import 'package:flutter_test/flutter_test.dart';
import 'package:freshqr/data/reference_data.dart';
import 'package:freshqr/services/scan_service.dart';
import 'package:freshqr/services/static_image_scan.dart';
import 'package:image/image.dart' as img;
import 'package:label_export/label_export.dart' as label_export;

Future<String> _oku(String p) => File(p).readAsString();

void main() {
  late Directory tmp;
  late String stem;
  final reference = ReferenceData(_oku);

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('freshqr_kalite_');
    final profile = await reference.sensorProfile('GENIPIN_PUTRESIN_v2_A');
    final recipe = await reference.layoutRecipe('QR_SENSOR_v4');
    final payload = label_export.buildLabelPayload(
      productId: 'KALITE-1',
      productType: 'levrek',
      productionDate: '2026-10-04',
      sensorProfileId: 'GENIPIN_PUTRESIN_v2_A',
      layoutVersion: 'QR_SENSOR_v4',
    );
    final uretilen = await label_export.exportLabel(payload, tmp,
        density: recipe.moduleDensity, sensorProfile: profile.raw);
    stem = uretilen.paths['png']!.uri.pathSegments.last.replaceAll('.png', '');
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
  });

  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    try {
      await tmp.delete(recursive: true);
    } catch (_) {}
  });

  test('bulanıklık artarken KABUL EDİLEN her sonuç doğru olmalı', () async {
    final kaynak = img.decodePng(
        await File('${tmp.path}/$stem.state_transition.png').readAsBytes())!;

    var kabulEdilen = 0;
    for (final yaricap in [0, 2, 4, 6, 8]) {
      final bozuk = yaricap == 0
          ? kaynak
          : img.gaussianBlur(img.Image.from(kaynak), radius: yaricap);
      final yol = '${tmp.path}/bulanik_$yaricap.png';
      await File(yol).writeAsBytes(img.encodePng(bozuk));

      final sonuc = await analyzePickedImagePath(yol, reference);
      if (sonuc is! ScanSuccess) continue; // QR hiç çözülmediyse konumuz değil
      if (sonuc.result.rescanRecommended) continue; // kapı elemiş, doğru davranış

      kabulEdilen++;
      expect(
        sonuc.result.technicalLevel,
        endsWith('P4'),
        reason: 'yarıçap $yaricap, kalite ${sonuc.result.qualityScore.toStringAsFixed(2)}: '
            'kapıdan geçti ama YANLIŞ sonuç verdi — eşik çok düşük',
      );
    }

    // Kapı her şeyi elerse test anlamsızlaşır; en az temiz görüntü geçmeli.
    expect(kabulEdilen, greaterThan(0), reason: 'hiçbir okuma kabul edilmedi');
  });
}
