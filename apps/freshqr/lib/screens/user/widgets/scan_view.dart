// user_view.py::_scan_view + _file_test_card + _recent_reads_card'ın Dart
// portu. Kamera henüz YOK (bkz. dosya başlığı notu diğer dosyalarda) —
// "Tazelik Tara" butonu ve "Test senaryoları" mock sonuçları tetikler.

import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/section_card.dart';
import '../../../data/label_store.dart';
import '../mock_results.dart';

class ScanView extends StatelessWidget {
  final VoidCallback onScan;
  final List<(String label, VoidCallback onTap)> testScenarios;

  /// Bu cihazda üretilmiş etiketler (gerçek dosyadan okuma testi için).
  final List<StoredLabel> storedLabels;
  final void Function(StoredLabel label, String state) onFileScan;

  const ScanView({
    super.key,
    required this.onScan,
    required this.testScenarios,
    this.storedLabels = const [],
    required this.onFileScan,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 220,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: scheme.secondaryContainer,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: scheme.outlineVariant, width: 2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.qr_code_scanner, size: 48, color: scheme.primary),
              const SizedBox(height: AppSpacing.s),
              Text('QR kodu çerçeveye alın', style: TextStyle(color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.m),
        SizedBox(
          height: 52,
          child: FilledButton.icon(
            onPressed: onScan,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Tazelik Tara'),
          ),
        ),
        const SizedBox(height: AppSpacing.m),
        SectionCard(
          title: 'Test senaryoları (geliştirme)',
          children: [
            Text(
              'Gerçek kamera/QR henüz bağlı değil — sonuç ekranlarını önizlemek için.',
              style: TextStyle(fontSize: AppTextSizes.caption, color: scheme.onSurfaceVariant),
            ),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.xs,
              children: [for (final (label, onTap) in testScenarios) TextButton(onPressed: onTap, child: Text(label))],
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.m),
        _fileTestCard(context),
        const SizedBox(height: AppSpacing.m),
        _recentReadsCard(context),
      ],
    );
  }

  Widget _fileTestCard(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    if (storedLabels.isEmpty) {
      return SectionCard(
        title: 'Dosyadan test et (gerçek analiz)',
        children: [
          Text(
            'Bu cihazda üretilmiş etiket yok. Önce Yönetici ekranından bir etiket oluşturun.',
            style: TextStyle(fontSize: AppTextSizes.caption, color: muted),
          ),
        ],
      );
    }
    return SectionCard(
      title: 'Dosyadan test et (gerçek analiz)',
      children: [
        Text(
          "Kamera yerine, ürettiğin bir etiketin sentetik durum görselini tüm okuyucu "
          'zincirinden (payload doğrulama, paketli profil, homografi, kalibrasyon, ΔE) '
          'geçirir — sonuç gerçek. (QR çözümü atlanır, metin etiket dosyasından alınır.)',
          style: TextStyle(fontSize: AppTextSizes.caption, color: muted),
        ),
        for (final label in storedLabels.take(5)) ...[
          const Divider(height: 1),
          Text(
            '${label.productType} · ${label.productId}',
            style: const TextStyle(fontSize: AppTextSizes.body, fontWeight: FontWeight.w500),
          ),
          Wrap(
            spacing: AppSpacing.xs,
            children: [
              for (final (key, text) in const [('fresh', 'Taze'), ('transition', 'Geçiş'), ('spoiled', 'Bozuk')])
                OutlinedButton(onPressed: () => onFileScan(label, key), child: Text(text)),
            ],
          ),
        ],
      ],
    );
  }

  Widget _recentReadsCard(BuildContext context) {
    if (mockRecentReads.isEmpty) {
      return SectionCard(
        title: 'Son okumalar',
        children: [Text('Henüz okuma yok.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))],
      );
    }
    final rows = <Widget>[];
    for (var i = 0; i < mockRecentReads.length; i++) {
      if (i > 0) rows.add(const Divider(height: 1));
      rows.add(_recentReadRow(context, mockRecentReads[i]));
    }
    return SectionCard(title: 'Son okumalar', children: rows);
  }

  Widget _recentReadRow(BuildContext context, RecentRead entry) {
    final label = freshnessLabels[entry.freshnessClass]!;
    final color = freshnessColors[entry.freshnessClass]!;
    final icon = freshnessIcons[entry.freshnessClass]!;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: AppSpacing.s),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${entry.product} · ${entry.productId}', style: const TextStyle(fontWeight: FontWeight.w500)),
                  Text(entry.when, style: TextStyle(fontSize: AppTextSizes.caption, color: scheme.onSurfaceVariant)),
                ],
              ),
            ],
          ),
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(fontSize: AppTextSizes.caption, fontWeight: FontWeight.w600, color: color)),
            ],
          ),
        ],
      ),
    );
  }
}
