// The light, dark and system themes with their shared colour tokens.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neiroha/presentation/theme/app_theme.dart';
import 'package:neiroha/presentation/theme/app_theme_mode.dart';

void main() {
  test('theme modes: dark by default, auto follows the system', () {
    expect(AppThemeSettings.parse(null), ThemeMode.dark);
    expect(AppThemeSettings.parse('system'), ThemeMode.system);
    expect(AppThemeSettings.parse('auto'), ThemeMode.system);
    expect(AppThemeSettings.parse('light'), ThemeMode.light);
    for (final mode in ThemeMode.values) {
      expect(AppThemeSettings.parse(AppThemeSettings.storageValue(mode)), mode);
    }
  });

  testWidgets('pages read the tokens of the theme in use', (tester) async {
    late Color fg, card, panel;
    Widget app(ThemeMode mode, Brightness system) => MediaQuery(
      data: MediaQueryData(platformBrightness: system),
      child: MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: mode,
        home: Builder(
          builder: (context) {
            fg = context.fg;
            card = Theme.of(context).cardTheme.color!;
            panel = context.colors.panel;
            return const SizedBox();
          },
        ),
      ),
    );

    await tester.pumpWidget(app(ThemeMode.dark, Brightness.light));
    expect(fg, AppColors.dark.fg);
    expect(card, AppColors.dark.card);
    expect(panel, AppColors.dark.panel);

    await tester.pumpWidget(app(ThemeMode.light, Brightness.dark));
    await tester.pumpAndSettle();
    expect(fg, AppColors.light.fg);
    expect(card, AppColors.light.card);

    await tester.pumpWidget(app(ThemeMode.system, Brightness.dark));
    await tester.pumpAndSettle();
    expect(fg, AppColors.dark.fg);
    await tester.pumpWidget(app(ThemeMode.system, Brightness.light));
    await tester.pumpAndSettle();
    expect(fg, AppColors.light.fg);
  });
}
