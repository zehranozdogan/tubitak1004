// Rapor §11'in "gerçek kamera koşulu" ruhuna daha yakın, daha zorlu
// sentetik testler — mevcut testler hep TEMİZ (PNG, bozulmasız) görüntü
// varsayıyordu. Python tarafındaki `tests/synthetic/test_realistic_
// distortions.py`nin Dart karşılığı (birebir port DEĞİL — Dart pipeline
// `analyzePickedImagePath` üzerinden GERÇEK dosya yoluyla test ediliyor,
// Python `analyze()`'i doğrudan çağırıyordu; motion blur burada basit
// tek-eksenli kutu bulanıklaştırma ile simüle ediliyor, cv2'nin döndürülmüş
// çizgi çekirdeği DEĞİL — amaç aynı: kalite düştükçe sistemin dürüstçe
// tepki verdiğini kanıtlamak, cv2 ile bit-bit eşleşmek değil).
//
// Amaç: fiziksel cihaz testine geçmeden (ya da telefon/emulator yokken)
// ucuza gerçekçi bozulma senaryolarında bug bulmak — kullanıcının gerçek
// şikayeti ("jpeg formatı, telefonla çekilmiş basılı etiket... çoğunda
// etiket bulunamadı") ile doğrudan ilgili.

import 'dart:io';

import 'package:flutter/foundation.dart' show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart' show TargetPlatform;
import 'package:flutter_test/flutter_test.dart';
import 'package:freshqr/data/reference_data.dart';
import 'package:freshqr/services/scan_service.dart';
import 'package:freshqr/services/static_image_scan.dart';
import 'package:image/image.dart' as img;
import 'package:label_export/label_export.dart' as label_export;
import 'package:qr_layout/qr_layout.dart' as qr_layout;

Future<String> _fileReader(String path) => File(path).readAsString();

/// Tek eksenli (yatay) kutu bulanıklaştırma — hareket bulanıklığının basit
/// bir simülasyonu (cv2'nin döndürülmüş çizgi çekirdeğinin BİREBİR AYNISI
/// DEĞİL, ama aynı temel özelliği taşır: yönlü, kademeli bulanıklaştırma).
img.Image _horizontalMotionBlur(img.Image src, int radius) {
  final out = img.Image.from(src);
  for (var y = 0; y < src.height; y++) {
    for (var x = 0; x < src.width; x++) {
      var r = 0, g = 0, b = 0, n = 0;
      for (var k = -radius; k <= radius; k++) {
        final sx = (x + k).clamp(0, src.width - 1);
        final p = src.getPixel(sx, y);
        r += p.r.toInt();
        g += p.g.toInt();
        b += p.b.toInt();
        n++;
      }
      out.setPixelRgb(x, y, r ~/ n, g ~/ n, b ~/ n);
    }
  }
  return out;
}

void main() {
  late Directory tmp;
  final reference = ReferenceData(_fileReader);

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('freshqr_distortion_');
    // bkz. static_image_scan_test.dart: flutter_test defaultTargetPlatform'u
    // Android'e sabitliyor, Windows'ta zxing2-yalnız yolu zorunlu kılmak için.
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
  });

  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    try {
      await tmp.delete(recursive: true);
    } catch (_) {}
  });

  Future<img.Image> renderLabel(String state, {String profileId = 'DEMO_QR_STATE_COLORS_v1'}) async {
    final profile = await reference.sensorProfile(profileId);
    final payload = label_export.buildLabelPayload(
      productId: 'TR55002',
      productType: 'levrek',
      productionDate: '2026-09-25',
      sensorProfileId: profileId,
      layoutVersion: 'QR_SENSOR_v4',
    );
    final label = label_export.generateLabel(payload, density: 'low');
    return qr_layout.renderLabelImage(label.qr, label.layoutJson, profile.raw, state: state);
  }

  group('JPEG sıkıştırma', () {
    test('gerçekçi-kötü JPEG kalitesinde (q=20) bile sınıflandırma sağlam kalır', () async {
      final clean = await renderLabel('fresh');
      final jpegBytes = img.encodeJpg(clean, quality: 20);
      final path = '${tmp.path}/label.jpg';
      await File(path).writeAsBytes(jpegBytes);

      final outcome = await analyzePickedImagePath(path, reference);
      expect(outcome, isA<ScanSuccess>(), reason: 'JPEG q=20 sonrası decode başarısız oldu');
      final s = outcome as ScanSuccess;
      expect(s.result.rescanRecommended, isFalse);
      expect(s.result.freshnessClass, 'fresh');
    });

    test('JPEG q=20, spoiled durumu da doğru sınıflanır', () async {
      final clean = await renderLabel('spoiled');
      final jpegBytes = img.encodeJpg(clean, quality: 20);
      final path = '${tmp.path}/label.jpg';
      await File(path).writeAsBytes(jpegBytes);

      final outcome = await analyzePickedImagePath(path, reference);
      expect((outcome as ScanSuccess).result.freshnessClass, 'spoiled');
    });
  });

  group('Hareket bulanıklığı', () {
    test('kalite skoru bulanıklık arttıkça DÜZGÜNCE azalır (rastgele sıçramaz)', () async {
      // BULGU (28 Eylül): radius=9+ zxing2'nin finder pattern tespitini
      // TAMAMEN kırıyor (decode başarısız, quality_score'a hiç ulaşmıyor)
      // -- yani "hafif bulanık ama okunabilir" aralığı zxing2 için oldukça
      // DAR. Bu, kullanıcının "çoğu fotoğrafta etiket bulunamadı" şikayeti
      // için olası bir katkı sebebi olabilir (gerçek elde-çekim fotoğrafları
      // bu radius=9 eşdeğerinden daha bulanık olabilir) -- ML Kit'in gerçek
      // cihazdaki bulanıklık toleransı muhtemelen daha yüksek (donanım
      // hızlandırmalı, farklı algoritma), bu yüzden ML Kit birincil decoder
      // olarak kalmalı; bu test sadece zxing2 YEDEĞİNİN kendi sınırını
      // belgeliyor.
      final clean = await renderLabel('fresh');
      final scores = <double>[];
      for (final radius in [0, 1, 2, 3]) {
        final blurred = radius == 0 ? clean : _horizontalMotionBlur(clean, radius);
        final path = '${tmp.path}/blur_$radius.png';
        await File(path).writeAsBytes(img.encodePng(blurred));
        final outcome = await analyzePickedImagePath(path, reference);
        final quality = switch (outcome) {
          ScanSuccess(:final result) => result.qualityScore,
          ScanInvalidQr() => null, // decode tamamen başarısız oldu -- bu testte beklenmiyor
        };
        expect(quality, isNotNull, reason: 'radius=$radius: decode başarısız oldu (bu testin kapsamı dışında)');
        scores.add(quality!);
      }
      for (var i = 1; i < scores.length; i++) {
        expect(scores[i], lessThanOrEqualTo(scores[i - 1]), reason: 'skorlar: $scores');
      }
    });

    test('ŞİDDETLİ bulanıklıkta sistem YANLIŞ ama emin bir sınıf üretmek yerine "yeniden tara" der (§7.1)', () async {
      final clean = await renderLabel('fresh');
      final severelyBlurred = _horizontalMotionBlur(clean, 20);
      final path = '${tmp.path}/severe_blur.png';
      await File(path).writeAsBytes(img.encodePng(severelyBlurred));

      final outcome = await analyzePickedImagePath(path, reference);
      switch (outcome) {
        case ScanSuccess(:final result):
          expect(result.rescanRecommended, isTrue, reason: 'decode başarılı oldu ama kalite kontrolü yakalamadı');
        case ScanInvalidQr():
          // Decode'un kendisi başarısız olması da KABUL EDİLEBİLİR bir dürüst
          // sonuç (§7.1) -- önemli olan YANLIŞ ama EMİN bir sınıf ÜRETMEMESİ.
          break;
      }
    });
  });
}
