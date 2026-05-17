enum AppFontMode {
  appDefault,
  system;

  static AppFontMode parse(String? value) {
    final normalized = value?.trim().toLowerCase();
    return switch (normalized) {
      'system' || 'system_font' || 'system-font' => AppFontMode.system,
      _ => AppFontMode.appDefault,
    };
  }

  String get storageValue {
    return switch (this) {
      AppFontMode.appDefault => 'default',
      AppFontMode.system => 'system',
    };
  }
}

class AppFontSettings {
  static const fontModeKey = 'app.fontMode';
  static const defaultMode = AppFontMode.appDefault;

  const AppFontSettings._();
}
