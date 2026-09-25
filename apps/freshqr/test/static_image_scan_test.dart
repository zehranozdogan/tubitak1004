// static_image_scan.dart testleri — GERÇEK bir PNG dosyasından (ImagePicker
// UI'sini atlayıp doğrudan dosya yoluyla) uçtan uca analiz. Bu ortamda
// ML Kit YOK (masaüstü/CI) — `cameraScanSupported=false` olduğundan zxing2
// yedeği kullanılır; bu da zxing2 yolunun GERÇEK bir dosyadan (bellekte
// üretilmiş bir görüntüden değil) çalıştığını ayrıca kanıtlar.

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

void main() {
  late Directory tmp;
  final reference = ReferenceData(_fileReader);

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('freshqr_staticscan_');
    // `flutter_test` otomatik test ortamında `defaultTargetPlatform`'u
    // KOŞULSUZ Android'e sabitliyor (host Windows olsa bile) — bu, "ML Kit
    // YOK, zxing2 yedeği kullanılıyor" senaryosunu (bu dosyanın asıl amacı)
    // yanlışlıkla atlatıp GERÇEK (bu ortamda arkası olmayan) BarcodeScanner
    // platform kanalını çağırtıyordu (elle bulundu). Windows'a sabitleyerek
    // niyeti (zxing2-yalnız yol) zorunlu kılıyoruz.
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
  });

  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    try {
      await tmp.delete(recursive: true);
    } catch (_) {}
  });

  Future<String> renderLabelPng(String state, {String profileId = 'DEMO_QR_STATE_COLORS_v1'}) async {
    final profile = await reference.sensorProfile(profileId);
    final payload = label_export.buildLabelPayload(
      productId: 'TR55001',
      productType: 'levrek',
      productionDate: '2026-09-25',
      sensorProfileId: profileId,
      layoutVersion: 'QR_SENSOR_v4',
    );
    final label = label_export.generateLabel(payload, density: 'low');
    final image = qr_layout.renderLabelImage(label.qr, label.layoutJson, profile.raw, state: state);
    final path = '${tmp.path}/label.png';
    await File(path).writeAsBytes(img.encodePng(image));
    return path;
  }

  test('gerçek PNG dosyasından uçtan uca: fresh -> ScanSuccess, freshnessClass=fresh', () async {
    final path = await renderLabelPng('fresh');
    final outcome = await analyzePickedImagePath(path, reference);
    expect(outcome, isA<ScanSuccess>());
    final s = outcome as ScanSuccess;
    expect(s.result.freshnessClass, 'fresh');
    expect(s.result.rescanRecommended, isFalse);
    expect(s.labelInfo.productId, 'TR55001');
  });

  test('spoiled durumu da doğru sınıflanır', () async {
    final path = await renderLabelPng('spoiled');
    final outcome = await analyzePickedImagePath(path, reference);
    expect((outcome as ScanSuccess).result.freshnessClass, 'spoiled');
  });

  test('QR içermeyen bir görsel -> ScanInvalidQr (çökmez)', () async {
    final blank = img.Image(width: 300, height: 300, numChannels: 3);
    img.fill(blank, color: img.ColorRgb8(255, 255, 255));
    final path = '${tmp.path}/blank.png';
    await File(path).writeAsBytes(img.encodePng(blank));
    final outcome = await analyzePickedImagePath(path, reference);
    expect(outcome, isA<ScanInvalidQr>());
  });

  test('bozuk/desteklenmeyen dosya -> ScanInvalidQr (çökmez)', () async {
    final path = '${tmp.path}/not_an_image.png';
    await File(path).writeAsBytes([1, 2, 3, 4, 5]);
    final outcome = await analyzePickedImagePath(path, reference);
    expect(outcome, isA<ScanInvalidQr>());
  });

  test('var olmayan dosya yolu -> hata fırlatır (çağıran taraf dosya seçiciden GEÇERLİ bir yol aldığını varsayar)', () async {
    expect(() => analyzePickedImagePath('${tmp.path}/yok.png', reference), throwsA(anything));
  });
}
