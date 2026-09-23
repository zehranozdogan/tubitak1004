// packages/ui_kit/components.py::section_card'ın Dart karşılığı.

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const SectionCard({super.key, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: const TextStyle(fontSize: AppTextSizes.heading, fontWeight: FontWeight.w600)),
            const SizedBox(height: AppSpacing.s),
            for (final child in children) Padding(padding: const EdgeInsets.only(bottom: AppSpacing.s), child: child),
          ],
        ),
      ),
    );
  }
}
