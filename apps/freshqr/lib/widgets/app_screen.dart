// packages/ui_kit/components.py::screen + app_header'ın Dart karşılığı —
// başlık çubuğu + ortalanmış/kaydırılabilir, `contentMaxWidth` genişliğinde
// bir gövde.

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppScreen extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final VoidCallback? onBack;
  final List<Widget>? actions;

  const AppScreen({super.key, required this.title, required this.children, this.onBack, this.actions});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: onBack == null ? null : IconButton(icon: const Icon(Icons.arrow_back), onPressed: onBack),
        automaticallyImplyLeading: false,
        actions: actions,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: contentMaxWidth),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.m),
              children: [
                for (final child in children) Padding(padding: const EdgeInsets.only(bottom: AppSpacing.m), child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
