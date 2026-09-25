import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/login_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Kamera ekranı sadece dikey tasarlandı (bkz. camera_scanner.dart'taki
  // döndürme varsayımı) — cihaz yatay çevrilirse hem önizleme hem ML Kit'e
  // verilen sensorOrientation tutarsızlaşır. Uygulamayı dikeye kilitle.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
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
