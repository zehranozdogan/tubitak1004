// user_view.py::_result_view'in Dart portu.
//
// Sonuç ekranı kuralı (§7.2, kritik):
// - rescanRecommended ise sınıf/seviye GÖSTERME, "Yeniden tara" göster.
// - freshnessClass yoksa (bilimsel eşik tanımlı değilse) "Taze/Geçiş/Bozuk"
//   UYDURMA; technicalLevel göster. Eşik tanımlandığında kod DEĞİŞMEDEN
//   freshnessClass dolu gelir ve üstteki dal otomatik devreye girer.

import 'package:color_engine/color_engine.dart';
import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/kv_row.dart';
import '../../../widgets/metric_bar.dart';
import '../../../widgets/section_card.dart';
import '../mock_results.dart';

class ResultView extends StatefulWidget {
  final ColorEngineResult result;
  final LabelInfo labelInfo;
  final VoidCallback onRescan;

  const ResultView({super.key, required this.result, required this.labelInfo, required this.onRescan});

  @override
  State<ResultView> createState() => _ResultViewState();
}

class _ResultViewState extends State<ResultView> {
  bool _showDetails = false;

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final scheme = Theme.of(context).colorScheme;

    if (result.rescanRecommended) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionCard(
            title: 'Okuma kalitesi yetersiz',
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppStateColors.transition),
                  const SizedBox(width: AppSpacing.s),
                  Expanded(
                    child: Text(
                      'Görüntü bulanık, parlamalı veya çok karanlık olabilir. '
                      'Yanlış sonuç göstermemek için tazelik sınıfı üretilmedi (§7.2).',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
              MetricBar(label: 'Okuma kalitesi', value: result.qualityScore),
            ],
          ),
          const SizedBox(height: AppSpacing.m),
          SizedBox(
            height: 52,
            child: FilledButton.icon(onPressed: widget.onRescan, icon: const Icon(Icons.refresh), label: const Text('Yeniden Tara')),
          ),
        ],
      );
    }

    final String headlineText;
    final Color headlineColor;
    final IconData? headlineIcon;
    if (result.freshnessClass != null) {
      headlineText = freshnessLabels[result.freshnessClass] ?? result.freshnessClass!.toUpperCase();
      headlineColor = freshnessColors[result.freshnessClass] ?? scheme.primary;
      headlineIcon = freshnessIcons[result.freshnessClass];
    } else {
      headlineText = result.technicalLevel ?? 'Sonuç yok';
      headlineColor = scheme.primary;
      headlineIcon = null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          title: 'Tazelik sonucu',
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (headlineIcon != null) ...[
                  Icon(headlineIcon, size: 28, color: headlineColor),
                  const SizedBox(width: AppSpacing.s),
                ],
                Flexible(
                  child: Text(
                    headlineText,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: AppTextSizes.title, fontWeight: FontWeight.bold, color: headlineColor),
                  ),
                ),
              ],
            ),
            KvRow('Ürün', widget.labelInfo.productType),
            KvRow('Parti', widget.labelInfo.productId),
            KvRow('Üretim tarihi', widget.labelInfo.productionDate),
            MetricBar(label: 'Okuma kalitesi', value: result.qualityScore),
          ],
        ),
        Center(
          child: TextButton(
            onPressed: () => setState(() => _showDetails = !_showDetails),
            child: Text(_showDetails ? 'Teknik detayları gizle' : 'Teknik detayları göster'),
          ),
        ),
        if (_showDetails)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.m),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MetricBar(label: 'Güven skoru', value: result.confidence),
                KvRow('ΔE', result.deltaE != null ? result.deltaE!.toStringAsFixed(2) : '—'),
                KvRow(
                  'Eşleşen profil noktası',
                  result.matchedProfilePoint != null ? result.matchedProfilePoint.toString() : '—',
                ),
                KvRow('Ölçülen modül', result.moduleReadings.length.toString()),
                for (final note in result.notes)
                  Text(note, style: TextStyle(fontSize: AppTextSizes.caption, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        SizedBox(
          height: 48,
          child: FilledButton.tonalIcon(onPressed: widget.onRescan, icon: const Icon(Icons.refresh), label: const Text('Yeniden Tara')),
        ),
      ],
    );
  }
}
