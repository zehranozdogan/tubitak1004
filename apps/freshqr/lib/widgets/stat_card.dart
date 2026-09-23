// packages/ui_kit/components.py::stat_card'ın Dart karşılığı.

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onTap;

  const StatCard({super.key, required this.label, required this.value, this.onTap});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final card = Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value, style: TextStyle(fontSize: AppTextSizes.title, fontWeight: FontWeight.bold, color: primary)),
            const SizedBox(height: AppSpacing.xs),
            Text(label, style: TextStyle(fontSize: AppTextSizes.caption, color: muted)),
          ],
        ),
      ),
    );
    if (onTap == null) return card;
    return InkWell(borderRadius: BorderRadius.circular(AppRadius.card), onTap: onTap, child: card);
  }
}
