// Etiketler listesi + detay + silme testleri. Geçici klasörde GERÇEK dosyalarla
// (label_payload/layout_version JSON) çalışır — path_provider'a bağımlı değil
// (LabelsScreen.dir enjekte edilir).

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:freshqr/data/label_store.dart';
import 'package:freshqr/screens/labels/labels_screen.dart';
import 'package:flutter/material.dart';

Future<void> _writeLabel(Directory dir, String id, {String layout = 'QR_SENSOR_v4'}) async {
  final stem = '${id}_$layout';
  await File('${dir.path}/$stem.label_payload.json').writeAsString(jsonEncode({
    'product_id': id,
    'product_type': 'LEVREK',
    'production_date': '2026-09-23',
    'sensor_profile_id': 'GENIPIN_PUTRESIN_v2',
    'layout_version': layout,
  }));
  await File('${dir.path}/$stem.layout_version.json').writeAsString(jsonEncode({
    'layout_version': layout,
    'qr_version': 12,
    'matrix_size': 65,
    'module_density': 'low',
    'sensor_modules': [
      [1, 2],
      [3, 4],
    ],
  }));
  await File('${dir.path}/$stem.state_fresh.png').writeAsBytes([1, 2, 3]);
}

Future<void> _loaded(WidgetTester tester) async {
  for (var i = 0; i < 40; i++) {
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 25)));
    await tester.pump(const Duration(milliseconds: 50));
    if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
  }
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 25)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('freshqr_labels_');
  });

  tearDown(() async {
    try {
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {
      // Windows dosya kilidi olabilir; geçici klasör, önemli değil.
    }
  });

  test('loadLabels: en yeniden eskiye sıralar, bozuk JSON atlanır', () async {
    await _writeLabel(dir, 'TR45678');
    await _writeLabel(dir, 'TR45679');
    await File('${dir.path}/BOZUK.label_payload.json').writeAsString('{not json');
    final labels = await loadLabels(dir);
    expect(labels.map((l) => l.productId), ['TR45679', 'TR45678']);
  });

  test('deleteLabel: stem ile başlayan tüm dosyaları siler, diğerine dokunmaz', () async {
    await _writeLabel(dir, 'TR45678');
    await _writeLabel(dir, 'TR45679');
    final n = await deleteLabel(dir, 'TR45678_QR_SENSOR_v4');
    expect(n, 3);
    final left = await loadLabels(dir);
    expect(left.map((l) => l.productId), ['TR45679']);
  });

  testWidgets('boş klasör -> bilgi metni', (tester) async {
    await tester.runAsync(() async {});
    await tester.pumpWidget(MaterialApp(home: LabelsScreen(dir: dir)));
    await _loaded(tester);
    expect(find.textContaining('Henüz etiket üretilmedi'), findsOneWidget);
  });

  testWidgets('liste -> detay -> sil akışı', (tester) async {
    await tester.runAsync(() => _writeLabel(dir, 'TR45678'));
    await tester.pumpWidget(MaterialApp(home: LabelsScreen(dir: dir)));
    await _loaded(tester);

    expect(find.text('Üretilen Etiketler (1)'), findsOneWidget);
    expect(find.text('TR45678 · LEVREK'), findsOneWidget);

    await tester.tap(find.text('TR45678 · LEVREK'));
    await _loaded(tester);

    expect(find.text('Layout bilgisi'), findsOneWidget);
    expect(find.text('v12'), findsOneWidget);
    expect(find.text('2'), findsOneWidget); // reaktif modül sayısı

    await tester.tap(find.byTooltip('Etiketi sil'));
    await tester.pumpAndSettle();
    expect(find.text('Etiketi sil'), findsOneWidget); // diyalog başlığı
    await tester.tap(find.text('Sil'));
    await _loaded(tester);

    expect(find.textContaining('Henüz etiket üretilmedi'), findsOneWidget);
    expect(await tester.runAsync(() => loadLabels(dir)), isEmpty);
  });
}
