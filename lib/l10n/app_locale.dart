import 'package:flutter/widgets.dart';

class AppLocaleSettings {
  static const localeKey = 'app.locale';
  static const defaultLocale = Locale('en');
  static const supportedLocales = <Locale>[Locale('en'), Locale('zh')];

  const AppLocaleSettings._();

  static Locale parse(String? value) {
    final code = value?.trim().toLowerCase();
    return switch (code) {
      'zh' || 'zh_cn' || 'zh-cn' || 'chinese' => const Locale('zh'),
      'en' || 'en_us' || 'en-us' || 'english' => const Locale('en'),
      _ => defaultLocale,
    };
  }

  static String storageValue(Locale locale) {
    if (locale.languageCode.toLowerCase().startsWith('zh')) return 'zh';
    return 'en';
  }
}
