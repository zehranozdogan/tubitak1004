// Uçtan uca: admin'in ürettiği GERÇEK etiket görselinden (renderLabelImage)
// okuyucu zinciri (payload -> paketli profil/tarif -> layout yeniden türetme
// -> analyzeFrame) doğru sonucu üretir. QR decode katmanı (ML Kit) hariç
// her şey gerçek.

import 'dart:convert';
import 'dart:io';

import 'package:color_engine/color_engine.dart' show Rgb, RgbImage, canonicalQrCorners;
import 'package:flutter_test/flutter_test.dart';
import 'package:freshqr/data/reference_data.dart';
import 'package:freshqr/services/scan_service.dart';
import 'package:label_export/label_export.dart' as label_export;
import 'package:qr_layout/qr_layout.dart' as qr_layout;

Future<String> _fileReader(String path) => File(path).readAsString();

label_export.GeneratedLabel _label({
  String profileId = 'DEMO_QR_STATE_COLORS_v1',
  String layoutVersion = 'QR_SENSOR_v4',
  String productId = 'TR45678',
}) {
  final payload = label_export.buildLabelPayload(
    productId: productId,
    productType: 'levrek',
    productionDate: '2026-09-23',
    sensorProfileId: profileId,
    layoutVersion: layoutVersion,
  );
  return label_export.generateLabel(payload, density: 'low');
}

Future<ScanOutcome> _scan(String state, {String profileId = 'DEMO_QR_STATE_COLORS_v1', String? qrTextOverride}) async {
  final ref = ReferenceData(_fileReader);
  final profile = await ref.sensorProfile(profileId);
  final label = _label(profileId: profileId);
  final image = qr_layout.renderLabelImage(label.qr, label.layoutJson, profile.raw, state: state);
  return analyzeCapturedLabel(
    qrText: qrTextOverride ?? label_export.labelPayloadQrText(label.payload),
    image: rgbImageFromImage(image),
    corners: canonicalQrCorners(label.layout.matrixSize),
    reference: ref,
  );
}

void main() {
  for (final state in const ['fresh', 'transition', 'spoiled']) {
    test('DEMO profili: $state görseli -> freshnessClass=$state, rescan yok', () async {
      final outcome = await _scan(state);
      expect(outcome, isA<ScanSuccess>());
      final s = outcome as ScanSuccess;
      expect(s.result.rescanRecommended, isFalse);
      expect(s.result.freshnessClass, state);
      expect(s.labelInfo.productType, 'Levrek');
      expect(s.labelInfo.productionDate, '23.09.2026');
    });
  }

  test('GENIPIN profili (eşik yok, §7.2): sınıf null, technicalLevel dolu; bozuk > taze profil noktası', () async {
    final fresh = (await _scan('fresh', profileId: 'GENIPIN_PUTRESIN_v2')) as ScanSuccess;
    final spoiled = (await _scan('spoiled', profileId: 'GENIPIN_PUTRESIN_v2')) as ScanSuccess;
    expect(fresh.result.freshnessClass, isNull);
    expect(fresh.result.technicalLevel, isNotNull);
    expect(spoiled.result.matchedProfilePoint!, greaterThan(fresh.result.matchedProfilePoint!));
  });

  test('JSON olmayan QR metni -> ScanInvalidQr', () async {
    expect(await _scan('fresh', qrTextOverride: 'https://ornek.com'), isA<ScanInvalidQr>());
  });

  test('şemaya uymayan JSON -> ScanInvalidQr', () async {
    expect(await _scan('fresh', qrTextOverride: jsonEncode({'a': 1})), isA<ScanInvalidQr>());
  });

  test('bilinmeyen sensor_profile_id -> ScanInvalidQr (çökmez)', () async {
    final label = _label();
    final text = jsonEncode({...label.payload.toJson(), 'sensor_profile_id': 'YOK_v9'});
    expect(await _scan('fresh', qrTextOverride: text), isA<ScanInvalidQr>());
  });

  test('yol geçişi denemesi (../) -> ScanInvalidQr', () async {
    final label = _label();
    final text = jsonEncode({...label.payload.toJson(), 'sensor_profile_id': '../../pubspec'});
    expect(await _scan('fresh', qrTextOverride: text), isA<ScanInvalidQr>());
  });

  test('GENIPIN: 12 farklı etikette (farklı açık/koyu dağılımı) 3 durumun seviyesi sabit, güven ~1.0 (sınıf-farkındalıklı okuma)', () async {
    final ref = ReferenceData(_fileReader);
    final profile = await ref.sensorProfile('GENIPIN_PUTRESIN_v2');
    final expected = {'fresh': 0.0625, 'transition': 0.25, 'spoiled': 1.0};
    for (var n = 45678; n < 45690; n++) {
      final label = _label(profileId: 'GENIPIN_PUTRESIN_v2', productId: 'TR$n');
      for (final state in expected.keys) {
        final image = qr_layout.renderLabelImage(label.qr, label.layoutJson, profile.raw, state: state);
        final outcome = await analyzeCapturedLabel(
          qrText: label_export.labelPayloadQrText(label.payload),
          image: rgbImageFromImage(image),
          corners: canonicalQrCorners(label.layout.matrixSize),
          reference: ref,
        ) as ScanSuccess;
        expect(outcome.result.matchedProfilePoint, expected[state], reason: 'TR$n $state');
        expect(outcome.result.confidence!, greaterThan(0.99), reason: 'TR$n $state');
      }
    }
  });

  test(
      'zxing2 yedek decoder yolu (finderPoints): ML Kit corners YERİNE zxing2\'nin finder '
      'noktalarından kestirilen köşelerle çalışır, ML Kit yoluyla AYNI sonucu verir', () async {
    final ref = ReferenceData(_fileReader);
    final profile = await ref.sensorProfile('DEMO_QR_STATE_COLORS_v1');
    final label = _label();
    final image = qr_layout.renderLabelImage(label.qr, label.layoutJson, profile.raw, state: 'transition');
    final rgbImage = rgbImageFromImage(image);
    final qrText = label_export.labelPayloadQrText(label.payload);

    final viaCorners = await analyzeCapturedLabel(
      qrText: qrText,
      image: rgbImage,
      corners: canonicalQrCorners(label.layout.matrixSize),
      reference: ref,
    ) as ScanSuccess;

    final decoded = qr_layout.decodeQrZxing(image);
    expect(decoded, isNotNull, reason: 'zxing2 bu görüntüyü çözebilmeli');
    expect(decoded!.finderPoints, isNotNull);
    final viaFinderPoints = await analyzeCapturedLabel(
      qrText: decoded.text,
      image: rgbImage,
      finderPoints: decoded.finderPoints,
      reference: ref,
    ) as ScanSuccess;

    expect(viaFinderPoints.result.freshnessClass, viaCorners.result.freshnessClass);
    expect(viaFinderPoints.result.deltaE, closeTo(viaCorners.result.deltaE!, 0.5));
    expect(viaFinderPoints.result.rescanRecommended, isFalse);
  });

  test('corners VE finderPoints ikisi de verilirse -> ArgumentError', () async {
    final ref = ReferenceData(_fileReader);
    final label = _label();
    expect(
      () => analyzeCapturedLabel(
        qrText: label_export.labelPayloadQrText(label.payload),
        image: RgbImage.filled(10, 10, const Rgb(0, 0, 0)),
        corners: canonicalQrCorners(label.layout.matrixSize),
        finderPoints: const qr_layout.QrFinderPoints(
          topLeft: (x: 0, y: 0),
          topRight: (x: 1, y: 0),
          bottomLeft: (x: 0, y: 1),
        ),
        reference: ref,
      ),
      throwsArgumentError,
    );
  });

  test('ne corners ne finderPoints verilirse -> ArgumentError', () async {
    final ref = ReferenceData(_fileReader);
    final label = _label();
    expect(
      () => analyzeCapturedLabel(
        qrText: label_export.labelPayloadQrText(label.payload),
        image: RgbImage.filled(10, 10, const Rgb(0, 0, 0)),
        reference: ref,
      ),
      throwsArgumentError,
    );
  });
}
