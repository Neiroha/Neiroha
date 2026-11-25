import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_font.dart';

export 'app_colors.dart';

/// Light and dark themes built from one Material 3 colour scheme, with the
/// app's own surfaces in [AppColors].
class AppTheme {
  static const accentColor = Color(0xFF7C3AED); // Deep purple accent
  static const sidebarWidth = 72.0;

  static ThemeData dark({AppFontMode fontMode = AppFontMode.appDefault}) =>
      _build(Brightness.dark, AppColors.dark, fontMode);

  static ThemeData light({AppFontMode fontMode = AppFontMode.appDefault}) =>
      _build(Brightness.light, AppColors.light, fontMode);

  static ThemeData _build(
    Brightness brightness,
    AppColors colors,
    AppFontMode fontMode,
  ) {
    final systemFont = fontMode == AppFontMode.system;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: accentColor,
          brightness: brightness,
        ).copyWith(
          surface: colors.background,
          surfaceContainerLowest: colors.background,
          surfaceContainerLow: colors.sidebar,
          surfaceContainer: colors.panel,
          surfaceContainerHigh: colors.card,
          surfaceContainerHighest: colors.raised,
          outlineVariant: colors.divider,
        );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      extensions: [colors],
      fontFamily: systemFont ? _systemFontFamily : null,
      fontFamilyFallback: systemFont ? _systemFontFallback : null,
      scaffoldBackgroundColor: colors.background,
      canvasColor: colors.background,
      // Pointer-driven desktops do not need 48 px touch targets.
      materialTapTargetSize: _desktop
          ? MaterialTapTargetSize.shrinkWrap
          : MaterialTapTargetSize.padded,
      cardTheme: CardThemeData(
        color: colors.card,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      dialogTheme: DialogThemeData(backgroundColor: colors.card),
      drawerTheme: DrawerThemeData(backgroundColor: colors.sidebar),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.field,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        isDense: _desktop,
        contentPadding: EdgeInsets.symmetric(
          horizontal: _desktop ? 12 : 14,
          vertical: _desktop ? 10 : 12,
        ),
      ),
      dividerTheme: DividerThemeData(color: colors.divider, thickness: 1),
    );
  }

  static bool get _desktop => switch (defaultTargetPlatform) {
    TargetPlatform.macOS ||
    TargetPlatform.windows ||
    TargetPlatform.linux => true,
    _ => false,
  };

  static String get _systemFontFamily {
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
