// Etiket detay ekranı: "… test et" düğmesi, etiketin sentetik durum
// görselini GERÇEK analiz zincirinden geçirir ve tamamlanmış okuma
// geçmişe yazılır. Bu yetenek 4 Ekim'de kullanıcı ekranındaki "Dosyadan
// test et" kartından buraya taşındı (kullanıcı akışı sadeleşsin diye);
// bu test onun KAYBOLMADIĞINI garanti eder.

import 'dart:io';

import 'package:flutter/foundation.dart' show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshqr/data/reference_data.dart';
import 'package:freshqr/data/scan_history.dart';
import 'package:freshqr/screens/labels/label_detail_screen.dart';
import 'package:label_export/label_export.dart' as label_export;

Future<void> _pumpReal(WidgetTester tester, {int rounds = 30}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 30)));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  // Gerçek dosya G/Ç'si setUp'ta — `testWidgets` gövdesinde FakeAsync
  // bölgesinde takılıyor (bkz. user_scan_history_widget_test.dart notu).
  late Directory tmp;
  late Directory labelsDir;
  late File historyFile;
  late String stem;
  final reference = ReferenceData((p) => File(p).readAsString());

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('freshqr_labeldetail_');
    labelsDir = Directory('${tmp.path}/labels')..createSync();
    historyFile = File('${tmp.path}/scan_history.json');

    final profile = await reference.sensorProfile('DEMO_QR_STATE_COLORS_v1');
    final recipe = await reference.layoutRecipe('QR_SENSOR_v4');
    final payload = label_export.buildLabelPayload(
      productId: 'TR90001',
      productType: 'somon',
      productionDate: '2026-09-25',
      sensorProfileId: 'DEMO_QR_STATE_COLORS_v1',
      layoutVersion: 'QR_SENSOR_v4',
    );
    final sonuc = await label_export.exportLabel(
      payload,
      labelsDir,
      density: recipe.moduleDensity,
      sensorProfile: profile.raw,
    );
    stem = sonuc.paths['png']!.uri.pathSegments.last.replaceAll('.png', '');
  });

  tearDown(() async {
    try {
      await tmp.delete(recursive: true);
    } catch (_) {}
  });

  testWidgets('"Bozuk test et" gerçek sonuç üretir ve geçmişe yazar', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    // "test et" artık GERÇEK kod çözme yolunu kullanıyor (7 Ekim); bu
    // ortamda ML Kit'in arkası yok, Windows'a sabitleyip zxing2 yolunu
    // zorunlu kılıyoruz. `testWidgets` gövde biterken debug değişkenlerin
    // sıfırlanmış olmasını şart koştuğu için setUp/tearDown değil, BURADA.
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;

    await tester.pumpWidget(MaterialApp(
      home: LabelDetailScreen(
        dir: labelsDir,
        stem: stem,
        reference: reference,
        historyFile: historyFile,
      ),
    ));
    await _pumpReal(tester);

    expect(await tester.runAsync(() => loadScanHistory(historyFile)), isEmpty);

    await tester.ensureVisible(find.widgetWithText(OutlinedButton, 'Bozuk test et'));
    await _pumpReal(tester, rounds: 3);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Bozuk test et'));
    await _pumpReal(tester);

    // Sonuç ekranı açıldı ve GERÇEK sınıfı gösteriyor.
    expect(find.text('BOZUK'), findsOneWidget);

    // Tamamlanmış okuma geçmişe yazıldı.
    final kayitlar = (await tester.runAsync(() => loadScanHistory(historyFile)))!;
    expect(kayitlar.length, 1);
    expect(kayitlar.single.productId, 'TR90001');
    expect(kayitlar.single.freshnessClass, 'spoiled');
    // Ölçüm detayları da kaydedilmeli (4 Ekim).
    expect(kayitlar.single.deltaE, isNotNull);
    expect(kayitlar.single.calibrationMethod, isNotNull);

    debugDefaultTargetPlatformOverride = null;
  });
}
