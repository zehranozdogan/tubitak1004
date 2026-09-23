// consumer/views/login_view.py'nin Dart portu — parola YOK, Yönetici/
// Kullanıcı seç, ilgili ekrana geç.

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/nav_tile.dart';
import 'admin/admin_screen.dart';
import 'user/user_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.m),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: contentMaxWidth),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.l),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.s),
                          decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(999)),
                          child: Icon(Icons.eco, size: 34, color: scheme.onPrimary),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s),
                      const Text(
                        'FreshQR',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: AppTextSizes.title, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Balık tazeliği — QR sensör etiketi okuyucu',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: AppTextSizes.body, color: muted),
                      ),
                      const SizedBox(height: AppSpacing.m),
                      NavTile(
                        title: 'Yönetici',
                        subtitle: 'Kalibrasyon profili ve etiket sürümü',
                        icon: Icons.admin_panel_settings,
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminScreen())),
                      ),
                      const SizedBox(height: AppSpacing.s),
                      NavTile(
                        title: 'Kullanıcı',
                        subtitle: 'Etiket tara, tazelik sonucu gör',
                        icon: Icons.qr_code_scanner,
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UserScreen())),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Prototip — parola istenmez.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: AppTextSizes.caption, color: muted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
