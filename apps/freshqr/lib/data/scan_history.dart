// Gerçek tarama geçmişi — consumer/views/user_view.py'deki `_MOCK_RECENT_
// READS` (sabit örnek veri) yerine bu cihazda YAPILMIŞ GERÇEK okumaları
// yerel bir JSON dosyasında tutar. SADECE tamamlanmış (rescanRecommended
// = false) okumalar kaydedilir — "Yeniden tara" ile biten yarım bir
// tarama GERÇEK bir sonuç değildir, geçmişe eklenmez (§7.1 ruhuyla
// tutarlı: kötü görüntüde sonuç üretilmez).
//
// "Test senaryoları" (Taze/Geçiş/Bozuk/... mock düğmeleri) BİLEREK
// kaydedilmez — bunlar gerçek bir ölçüm değil, ekran önizlemesi; geçmişe
// eklemek "dürüst sonuç" ilkesiyle çelişirdi.

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

const int _maxEntries = 30;

class ScanHistoryEntry {
  final String productType;
  final String productId;
  final DateTime when;
  final String? freshnessClass; // null olabilir (§7.2: eşik yoksa sınıf yok)
  final String? technicalLevel;

  const ScanHistoryEntry({
    required this.productType,
    required this.productId,
    required this.when,
    this.freshnessClass,
    this.technicalLevel,
  });

  Map<String, dynamic> toJson() => {
        'product_type': productType,
        'product_id': productId,
        'when': when.toIso8601String(),
        if (freshnessClass != null) 'freshness_class': freshnessClass,
        if (technicalLevel != null) 'technical_level': technicalLevel,
      };

  static ScanHistoryEntry? tryFromJson(dynamic json) {
    if (json is! Map<String, dynamic>) return null;
    final productType = json['product_type'];
    final productId = json['product_id'];
    final whenStr = json['when'];
    if (productType is! String || productId is! String || whenStr is! String) return null;
    final when = DateTime.tryParse(whenStr);
    if (when == null) return null;
    return ScanHistoryEntry(
      productType: productType,
      productId: productId,
      when: when,
      freshnessClass: json['freshness_class'] as String?,
      technicalLevel: json['technical_level'] as String?,
    );
  }
}

Future<File> defaultScanHistoryFile() async {
  final docs = await getApplicationDocumentsDirectory();
  return File('${docs.path}/scan_history.json');
}

Future<List<ScanHistoryEntry>> loadScanHistory(File file) async {
  if (!await file.exists()) return const [];
  try {
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! List) return const [];
    return [for (final e in decoded) ?ScanHistoryEntry.tryFromJson(e)];
  } catch (_) {
    return const [];
  }
}

/// Yeni girdiyi en başa ekler, `_maxEntries`'i aşarsa en eskileri atar.
/// Güncel (yeniden eskiye sıralı) listeyi döner.
Future<List<ScanHistoryEntry>> appendScanHistory(File file, ScanHistoryEntry entry) async {
  final current = await loadScanHistory(file);
  final updated = [entry, ...current].take(_maxEntries).toList();
  await file.parent.create(recursive: true);
  await file.writeAsString(jsonEncode([for (final e in updated) e.toJson()]));
  return updated;
}
