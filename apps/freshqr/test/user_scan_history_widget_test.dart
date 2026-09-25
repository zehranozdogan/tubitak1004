// Kullanıcı ekranı: "Dosyadan test et" ile GERÇEK bir tarama tamamlanınca
// "Son okumalar"a eklenir; "Test senaryoları" (mock) EKLENMEZ (bkz.
// data/scan_history.dart dosya başlığı).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshqr/data/reference_data.dart';
import 'package:freshqr/data/scan_history.dart';
import 'package:freshqr/screens/user/user_screen.dart';
import 'package:label_export/label_export.dart' as label_export;

Future<void> _pumpReal(WidgetTester tester, {int rounds = 30}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 30)));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  // Gerçek dosya G/Ç'si (Directory.createTemp, dosya okuma/yazma) doğrudan
  // `testWidgets` gövdesi içinde çağrılırsa FakeAsync bölgesinde SONSUZA
  // TAKILIYOR (elle doğrulandı, "did not complete") — bu yüzden kurulum
  // `setUp`'ta (diğer geçen testlerle AYNI desen, bkz. labels_screen_test.dart),
  // gövde içindeki tek seferlik G/Ç çağrıları da `tester.runAsync(...)` ile.
  late Directory tmp;
  late Directory labelsDir;
  late File historyFile;
  final reference = ReferenceData((p) => File(p).readAsString());

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('freshqr_userhist_');
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
    await label_export.exportLabel(payload, labelsDir, density: recipe.moduleDensity, sensorProfile: profile.raw);
  });

  tearDown(() async {
    try {
      await tmp.delete(recursive: true);
    } catch (_) {}
  });

  testWidgets('gerçek dosya taraması -> Son okumalar\'a eklenir; mock test senaryosu eklenmez', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(MaterialApp(
      home: UserScreen(labelsDir: labelsDir, historyFile: historyFile, reference: reference),
    ));
    await _pumpReal(tester);

    // Önce mock bir test senaryosu çalıştır — BU geçmişe eklenmemeli.
    // (Sahte etiket zaten mevcut olduğu için "Test senaryoları" kartındaki
    // TextButton ile dosya-test kartındaki OutlinedButton'ı ayırt etmek gerekir.)
    await tester.tap(find.widgetWithText(TextButton, 'Taze'));
    await _pumpReal(tester, rounds: 5);
    await tester.tap(find.text('Yeniden Tara'));
    await _pumpReal(tester, rounds: 5);

    expect(find.textContaining('Henüz okuma yok'), findsOneWidget);
    expect(await tester.runAsync(() => loadScanHistory(historyFile)), isEmpty);

    // Gerçek dosya taraması: Somon · TR90001, Bozuk.
    await tester.tap(find.widgetWithText(OutlinedButton, 'Bozuk'));
    await _pumpReal(tester);
    expect(find.text('BOZUK'), findsOneWidget);

    await tester.tap(find.text('Yeniden Tara'));
    await _pumpReal(tester);

    expect(find.textContaining('Henüz okuma yok'), findsNothing);
    expect(find.textContaining('Somon · TR90001'), findsOneWidget);

    final saved = (await tester.runAsync(() => loadScanHistory(historyFile)))!;
    expect(saved.length, 1);
    expect(saved.single.freshnessClass, 'spoiled');
    expect(saved.single.productId, 'TR90001');
  });
}
