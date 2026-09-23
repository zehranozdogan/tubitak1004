// Tasarım tokenleri — packages/ui_kit/theme.py'nin (Flet prototipi) Dart
// karşılığı. Aynı isimlendirme/değerler bilinçli olarak korundu ki iki
// prototip (Flet ve Flutter) görsel olarak tutarlı kalsın.

import 'package:flutter/material.dart';

class AppSpacing {
  static const double xs = 4;
  static const double s = 8;
  static const double m = 16;
  static const double l = 24;
}

class AppRadius {
  static const double card = 16;
  static const double button = 12;
}

const double contentMaxWidth = 480;

class AppTextSizes {
  static const double title = 26;
  static const double heading = 18;
  static const double body = 14;
  static const double caption = 12;
}

/// Tazelik durum renkleri (rapor §7 — yalnızca doğrulanmış eşik varsa
/// gösterilir). Python ui_kit.theme: C_FRESH/C_TRANSITION/C_SPOILED.
/// NOT: bunlar qr_layout paketindeki STATE_COLORS (sensör pigment rengi,
/// etiket üretiminde kullanılır) İLE KARIŞTIRILMAMALI — buradakiler UI'daki
/// durum rozeti/trafik ışığı renkleri, farklı bir kavram.
class AppStateColors {
  static const Color fresh = Color(0xFF2E7D32); // Colors.green[800] tonu
  static const Color transition = Color(0xFFEF6C00); // Colors.orange[800]
  static const Color spoiled = Color(0xFFC62828); // Colors.red[800]
}

const Map<String, String> freshnessLabels = {
  'fresh': 'TAZE',
  'transition': 'GEÇİŞ',
  'spoiled': 'BOZUK',
};

const Map<String, Color> freshnessColors = {
  'fresh': AppStateColors.fresh,
  'transition': AppStateColors.transition,
  'spoiled': AppStateColors.spoiled,
};

const Map<String, IconData> freshnessIcons = {
  'fresh': Icons.check_circle,
  'transition': Icons.warning_amber_rounded,
  'spoiled': Icons.cancel,
};

const Color _seed = Color(0xFF00658F); // packages/ui_kit/theme.py::SEED

ThemeData buildAppTheme() {
  final colorScheme = ColorScheme.fromSeed(seedColor: _seed);
  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: colorScheme.surfaceContainer,
    appBarTheme: AppBarTheme(
      backgroundColor: colorScheme.primaryContainer,
      foregroundColor: colorScheme.onPrimaryContainer,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: AppTextSizes.heading,
        fontWeight: FontWeight.w600,
        color: colorScheme.onPrimaryContainer,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.all(14),
    ),
  );
}
