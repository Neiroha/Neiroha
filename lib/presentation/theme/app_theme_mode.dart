import 'package:flutter/material.dart';

/// Light, dark, or following the system, stored as `app.themeMode`.
/// Dark stays the default, as it was the only look before.
class AppThemeSettings {
  static const themeModeKey = 'app.themeMode';
  static const defaultMode = ThemeMode.dark;

  const AppThemeSettings._();

  static ThemeMode parse(String? value) =>
      switch (value?.trim().toLowerCase()) {
        'system' || 'auto' => ThemeMode.system,
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => defaultMode,
      };

  static String storageValue(ThemeMode mode) => mode.name;
}
