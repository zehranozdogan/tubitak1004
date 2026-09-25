// scan_history.dart testleri — gerçek geçici dosyayla (path_provider'a
// bağımlı değil, defaultScanHistoryFile enjekte edilmiyor, doğrudan File
// veriliyor).

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:freshqr/data/scan_history.dart';

void main() {
  late Directory dir;
  late File file;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('freshqr_history_');
    file = File('${dir.path}/scan_history.json');
  });

  tearDown(() async {
    try {
      await dir.delete(recursive: true);
    } catch (_) {}
  });

  test('dosya yoksa boş liste (çökmez)', () async {
    expect(await loadScanHistory(file), isEmpty);
  });

  test('bozuk JSON -> boş liste (çökmez)', () async {
    await file.writeAsString('{not json');
    expect(await loadScanHistory(file), isEmpty);
  });

  test('appendScanHistory: en başa ekler (yeniden eskiye)', () async {
    final a = ScanHistoryEntry(productType: 'Levrek', productId: 'TR1', when: DateTime(2026, 9, 20));
    final b = ScanHistoryEntry(productType: 'Levrek', productId: 'TR2', when: DateTime(2026, 9, 21));
    await appendScanHistory(file, a);
    final after = await appendScanHistory(file, b);
    expect(after.map((e) => e.productId), ['TR2', 'TR1']);
  });

  test('freshnessClass ve technicalLevel disk üzerinden aynen geri gelir', () async {
    final withClass = ScanHistoryEntry(productType: 'Levrek', productId: 'TR1', when: DateTime(2026, 9, 20), freshnessClass: 'spoiled');
    final withoutClass = ScanHistoryEntry(
      productType: 'Levrek',
      productId: 'TR2',
      when: DateTime(2026, 9, 21),
      technicalLevel: 'Renk seviyesi 2 / Profil noktası P2',
    );
    await appendScanHistory(file, withClass);
    final after = await appendScanHistory(file, withoutClass);
    expect(after[0].freshnessClass, isNull);
    expect(after[0].technicalLevel, 'Renk seviyesi 2 / Profil noktası P2');
    expect(after[1].freshnessClass, 'spoiled');
    expect(after[1].technicalLevel, isNull);
  });

  test('30 kaydı aşınca en eskiler atılır (_maxEntries)', () async {
    for (var i = 0; i < 35; i++) {
      await appendScanHistory(file, ScanHistoryEntry(productType: 'Levrek', productId: 'TR$i', when: DateTime(2026, 1, 1).add(Duration(minutes: i))));
    }
    final all = await loadScanHistory(file);
    expect(all.length, 30);
    expect(all.first.productId, 'TR34'); // en yeni en başta
    expect(all.last.productId, 'TR5'); // en eski 5 tanesi (0-4) atıldı
  });

  test('diskteki JSON biçimi beklenen alan adlarını kullanır (snake_case)', () async {
    await appendScanHistory(
      file,
      ScanHistoryEntry(productType: 'Levrek', productId: 'TR1', when: DateTime(2026, 9, 20, 14, 30), freshnessClass: 'fresh'),
    );
    final raw = jsonDecode(await file.readAsString()) as List;
    expect(raw.single, {
      'product_type': 'Levrek',
      'product_id': 'TR1',
      'when': DateTime(2026, 9, 20, 14, 30).toIso8601String(),
      'freshness_class': 'fresh',
    });
  });
}
