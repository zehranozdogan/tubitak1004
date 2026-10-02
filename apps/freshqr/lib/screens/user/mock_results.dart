// user_view.py'deki mock ColorEngineResult senaryolarının Dart portu —
// kamera/gerçek analiz bağlanana kadar sonuç ekranının TÜM dallarını
// (taze/geçiş/bozuk/düşük-kalite/izin-yok/geçersiz-QR) önizlemek için.
// GERÇEK `color_engine.ColorEngineResult` tipini kullanır (mock ayrı bir
// tip DEĞİL) — ileride tek değişecek şey bu değerlerin `analyzeFrame()`'den
// gelmesi olacak, tip aynı kalacak.

import 'package:color_engine/color_engine.dart';

class LabelInfo {
  final String productType;
  final String productId;
  final String productionDate;
  // Hangi kalibrasyon yönteminin uygulandığı (sensor_profile'dan gelir —
  // etiketten DEĞİL, bkz. docs/decisions/0004 "KRİTİK (2 Ekim)"). Sonuç
  // ekranındaki teknik detaylarda gösteriliyor: A/B/C karşılaştırmasında
  // doğru yöntemin uygulandığı cihazda gözle doğrulanabilsin diye.
  final String? calibrationMethod;

  const LabelInfo({
    required this.productType,
    required this.productId,
    required this.productionDate,
    this.calibrationMethod,
  });
}

const mockLabelInfo = LabelInfo(productType: 'Levrek', productId: 'TR45678', productionDate: '10.09.2026');

const mockOk = ColorEngineResult(
  qualityScore: 0.86,
  rescanRecommended: false,
  technicalLevel: 'Renk seviyesi 2 / Profil noktası P4',
  confidence: 0.78,
  deltaE: 4.1,
  matchedProfilePoint: 0.125,
  notes: ['Mock veri — analyzeFrame() henüz bağlı değil (rapor §6.2).'],
);

const mockRescan = ColorEngineResult(
  qualityScore: 0.31,
  rescanRecommended: true,
  notes: ['Mock veri — düşük kalite senaryosu (parlama / bulanıklık).'],
);

const mockFresh = ColorEngineResult(
  qualityScore: 0.91,
  rescanRecommended: false,
  freshnessClass: 'fresh',
  confidence: 0.88,
  deltaE: 2.3,
  matchedProfilePoint: 0.03125,
  notes: ['Mock veri — doğrulanmış eşik senaryosu (henüz gelmedi, önizleme).'],
);

const mockTransition = ColorEngineResult(
  qualityScore: 0.84,
  rescanRecommended: false,
  freshnessClass: 'transition',
  confidence: 0.71,
  deltaE: 6.8,
  matchedProfilePoint: 0.25,
  notes: ['Mock veri — doğrulanmış eşik senaryosu (henüz gelmedi, önizleme).'],
);

const mockSpoiled = ColorEngineResult(
  qualityScore: 0.90,
  rescanRecommended: false,
  freshnessClass: 'spoiled',
  confidence: 0.93,
  deltaE: 11.4,
  matchedProfilePoint: 1.0,
  notes: ['Mock veri — doğrulanmış eşik senaryosu (henüz gelmedi, önizleme).'],
);

// "Son okumalar" artık GERÇEK (bkz. data/scan_history.dart) — burada mock
// veri kaldırıldı (25 Eylül).
