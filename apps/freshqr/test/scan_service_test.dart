// Uçtan uca: admin'in ürettiği GERÇEK etiket görselinden (renderLabelImage)
// okuyucu zinciri (payload -> paketli profil/tarif -> layout yeniden türetme
// -> analyzeFrame) doğru sonucu üretir. QR decode katmanı (ML Kit) hariç
// her şey gerçek.

import 'dart:convert';
import 'dart:io';

import 'package:color_engine/color_engine.dart' show canonicalQrCorners;
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
}
