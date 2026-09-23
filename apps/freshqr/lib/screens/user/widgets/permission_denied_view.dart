// user_view.py::_permission_denied_view'in Dart portu.

import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/section_card.dart';

class PermissionDeniedView extends StatelessWidget {
  final VoidCallback onRetry;

  const PermissionDeniedView({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          title: 'Kamera izni gerekli',
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.no_photography_outlined, color: scheme.onSurfaceVariant),
                const SizedBox(width: AppSpacing.s),
                Expanded(
                  child: Text(
                    'Etiketi tarayabilmek için kamera izni gerekiyor. '
                    'Cihaz ayarlarından FreshQR için kamera iznini açın.',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.m),
        SizedBox(
          height: 52,
          child: FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Tekrar Dene')),
        ),
      ],
    );
  }
}
