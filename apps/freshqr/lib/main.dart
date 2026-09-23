import 'package:flutter/material.dart';

import 'screens/login_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const FreshQrApp());
}

class FreshQrApp extends StatelessWidget {
  const FreshQrApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FreshQR',
      theme: buildAppTheme(),
      home: const LoginScreen(),
    );
  }
}
