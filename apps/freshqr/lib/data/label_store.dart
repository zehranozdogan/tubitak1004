// consumer/labels.py'nin Dart portu — üretilmiş etiketleri yerel klasörden
// okur/siler. Bu SADECE bu cihazın kendi ürettiği etiketlerin geçmişi;
// dağıtılan referans veriyle (sensor_profile/layout_version) karıştırılmamalı
// (bkz. docs/decisions/0005-statik-veri-db-yok.md).
//
// `dir` verilebilir (test için); verilmezse admin ekranıyla AYNI klasör
// (uygulama belge dizini/labels) kullanılır.

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

const String _suffix = '.label_payload.json';

class StoredLabel {
  final String stem;
  final Map<String, dynamic> payload;

  const StoredLabel({required this.stem, required this.payload});

  String get productId => (payload['product_id'] as String?) ?? stem;
  String get productType => (payload['product_type'] as String?) ?? '—';
  String get productionDate => (payload['production_date'] as String?) ?? '—';
  String get sensorProfileId => (payload['sensor_profile_id'] as String?) ?? '—';
  String get layoutVersion => (payload['layout_version'] as String?) ?? '—';
}

Future<Directory> defaultLabelsDir() async {
  final docs = await getApplicationDocumentsDirectory();
  return Directory('${docs.path}/labels');
}

/// Üretilmiş etiketleri en yeniden en eskiye (dosya adına göre ters sıra,
/// Python `sorted(..., reverse=True)` ile aynı) döndürür.
Future<List<StoredLabel>> loadLabels(Directory dir) async {
  if (!await dir.exists()) return [];
  final files = <File>[];
  await for (final entry in dir.list()) {
    if (entry is File && entry.uri.pathSegments.last.endsWith(_suffix)) files.add(entry);
  }
  files.sort((a, b) => b.path.compareTo(a.path));
  final labels = <StoredLabel>[];
  for (final f in files) {
    try {
      final payload = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      final name = f.uri.pathSegments.last;
      labels.add(StoredLabel(stem: name.substring(0, name.length - _suffix.length), payload: payload));
    } catch (_) {
      continue;
    }
  }
  return labels;
}

Future<Map<String, dynamic>> readJson(File file) async {
  try {
    return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
  } catch (_) {
    return {};
  }
}

/// `stem` ile başlayan tüm dosyaları (json/png, 3 durum görseli) siler;
/// silinen dosya sayısını döndürür.
Future<int> deleteLabel(Directory dir, String stem) async {
  if (!await dir.exists()) return 0;
  var deleted = 0;
  await for (final entry in dir.list()) {
    if (entry is! File) continue;
    if (entry.uri.pathSegments.last.startsWith('$stem.')) {
      try {
        await entry.delete();
        deleted++;
      } catch (_) {}
    }
  }
  return deleted;
}
