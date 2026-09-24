// packages/ui_kit/components.py::kv'nin Dart karşılığı.

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class KvRow extends StatelessWidget {
  final String label;
  final String value;

  const KvRow(this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: muted, fontSize: AppTextSizes.body)),
        const SizedBox(width: AppSpacing.s),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: AppTextSizes.body, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
