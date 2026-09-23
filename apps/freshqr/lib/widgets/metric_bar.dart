// user_view.py::_metric_bar'ın Dart karşılığı — 0..1 aralığında bir skoru
// (okuma kalitesi, güven skoru) etiket + ilerleme çubuğuyla gösterir.

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class MetricBar extends StatelessWidget {
  final String label;
  final double? value; // null -> "—"

  const MetricBar({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ratio = value == null ? 0.0 : value!.clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: AppTextSizes.body)),
            Text(
              value == null ? '—' : value!.toStringAsFixed(2),
              style: const TextStyle(fontSize: AppTextSizes.body, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 6,
            color: scheme.primary,
            backgroundColor: scheme.outlineVariant,
          ),
        ),
      ],
    );
  }
}
