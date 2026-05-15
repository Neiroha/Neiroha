import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_font.dart';

class AppTheme {
  static const accentColor = Color(0xFF7C3AED); // Deep purple accent
  static const sidebarWidth = 72.0;

  static ThemeData dark({AppFontMode fontMode = AppFontMode.appDefault}) {
    final systemFont = fontMode == AppFontMode.system;
    return ThemeData(
      colorSchemeSeed: accentColor,
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: systemFont ? _systemFontFamily : null,
      fontFamilyFallback: systemFont ? _systemFontFallback : null,
      scaffoldBackgroundColor: const Color(0xFF0F0F14),
      cardTheme: const CardThemeData(
        color: Color(0xFF1A1A24),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1A1A24),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF2A2A36),
        thickness: 1,
      ),
    );
  }

  static const sidebarBg = Color(0xFF12121A);
  static const surfaceDim = Color(0xFF16161E);
  static const surfaceBright = Color(0xFF1E1E2A);

  static String get _systemFontFamily {
    if (kIsWeb) return 'system-ui';
    return switch (defaultTargetPlatform) {
      TargetPlatform.windows => 'Segoe UI',
      TargetPlatform.macOS || TargetPlatform.iOS => '.AppleSystemUIFont',
      TargetPlatform.android => 'sans-serif',
      TargetPlatform.linux => 'Ubuntu',
      TargetPlatform.fuchsia => 'Roboto',
    };
  }

  static const _systemFontFallback = <String>[
    'Segoe UI',
    'Microsoft YaHei UI',
    'Microsoft YaHei',
    'PingFang SC',
    'Noto Sans CJK SC',
    'Noto Sans SC',
    'Roboto',
    'Arial',
    'sans-serif',
  ];
}
