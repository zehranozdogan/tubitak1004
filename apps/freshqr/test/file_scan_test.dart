// Admin'in GERÇEK exportLabel çıktısı (dosyalar) -> scanStoredLabel: kamerasız
// uçtan uca okuma. Paketli referans veri (assets/reference) dosyadan okunur.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:freshqr/data/reference_data.dart';
import 'package:freshqr/services/file_scan.dart';
import 'package:freshqr/services/scan_service.dart';
import 'package:label_export/label_export.dart' as label_export;

void main() {
  late Directory dir;
  final reference = ReferenceData((p) => File(p).readAsString());

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('freshqr_filescan_');
  });

  tearDown(() async {
    try {
      await dir.delete(recursive: true);
    } catch (_) {}
  });

  Future<String> exportWith(String profileId) async {
    final profile = await reference.sensorProfile(profileId);
    final recipe = await reference.layoutRecipe('QR_SENSOR_v4');
    final payload = label_export.buildLabelPayload(
      productId: 'TR45678',
      productType: 'levrek',
      productionDate: '2026-09-23',
      sensorProfileId: profileId,
      layoutVersion: 'QR_SENSOR_v4',
    );
    await label_export.exportLabel(payload, dir, density: recipe.moduleDensity, sensorProfile: profile.raw);
    return 'TR45678_QR_SENSOR_v4';
  }

  for (final state in const ['fresh', 'transition', 'spoiled']) {
    test('exportLabel -> scanStoredLabel: $state (DEMO profili, sınıf eşleşir)', () async {
      final stem = await exportWith('DEMO_QR_STATE_COLORS_v1');
      final outcome = await scanStoredLabel(dir: dir, stem: stem, state: state, reference: reference);
      expect(outcome, isA<ScanSuccess>());
      expect((outcome as ScanSuccess).result.freshnessClass, state);
    });
  }

  test('eksik görsel -> ScanInvalidQr (çökmez)', () async {
    final stem = await exportWith('GENIPIN_PUTRESIN_v2');
    await File('${dir.path}/$stem.state_fresh.png').delete();
    final outcome = await scanStoredLabel(dir: dir, stem: stem, state: 'fresh', reference: reference);
    expect(outcome, isA<ScanInvalidQr>());
  });

  test('bozuk PNG -> ScanInvalidQr', () async {
    final stem = await exportWith('GENIPIN_PUTRESIN_v2');
    await File('${dir.path}/$stem.state_fresh.png').writeAsBytes([1, 2, 3]);
    final outcome = await scanStoredLabel(dir: dir, stem: stem, state: 'fresh', reference: reference);
    expect(outcome, isA<ScanInvalidQr>());
  });
}
