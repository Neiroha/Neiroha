import 'package:flutter/material.dart';

/// The app's own colour tokens, one set per brightness, carried by the
/// theme so every page reads the same surfaces in light and dark.
///
/// Layers, from back to front: [background] (the page), [sidebar],
/// [panel] (insets and side panes), [card], [raised] (hover, selection,
/// chips). [fg] is the foreground that muted text, icons, borders and
/// tints are drawn from with an alpha, in place of a fixed white.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.sidebar,
    required this.panel,
    required this.card,
    required this.raised,
    required this.field,
    required this.divider,
    required this.fg,
    required this.success,
    required this.warning,
    required this.danger,
  });

  final Color background;
  final Color sidebar;
  final Color panel;
  final Color card;
  final Color raised;
  final Color field;
  final Color divider;
  final Color fg;
  final Color success;
  final Color warning;
  final Color danger;

  static const dark = AppColors(
    background: Color(0xFF0F0F14),
    sidebar: Color(0xFF12121A),
    panel: Color(0xFF16161E),
    card: Color(0xFF1A1A24),
    raised: Color(0xFF1E1E2A),
    field: Color(0xFF1A1A24),
    divider: Color(0xFF2A2A36),
    fg: Colors.white,
    success: Color(0xFF4ADE80),
    warning: Color(0xFFFFC107),
    danger: Color(0xFFFF5252),
  );

  static const light = AppColors(
    background: Color(0xFFF4F4F7),
    sidebar: Color(0xFFEBEBF0),
    panel: Color(0xFFF0F0F4),
    card: Color(0xFFFFFFFF),
    raised: Color(0xFFE7E7EE),
    field: Color(0xFFF0F0F4),
    divider: Color(0xFFDCDCE4),
    fg: Color(0xFF17171F),
    success: Color(0xFF16A34A),
    warning: Color(0xFFB45309),
    danger: Color(0xFFDC2626),
  );

  @override
  AppColors copyWith({
    Color? background,
    Color? sidebar,
    Color? panel,
    Color? card,
    Color? raised,
    Color? field,
    Color? divider,
    Color? fg,
    Color? success,
    Color? warning,
    Color? danger,
  }) => AppColors(
    background: background ?? this.background,
    sidebar: sidebar ?? this.sidebar,
    panel: panel ?? this.panel,
    card: card ?? this.card,
    raised: raised ?? this.raised,
    field: field ?? this.field,
    divider: divider ?? this.divider,
    fg: fg ?? this.fg,
    success: success ?? this.success,
    warning: warning ?? this.warning,
    danger: danger ?? this.danger,
  );

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      background: mix(background, other.background),
      sidebar: mix(sidebar, other.sidebar),
      panel: mix(panel, other.panel),
      card: mix(card, other.card),
      raised: mix(raised, other.raised),
      field: mix(field, other.field),
      divider: mix(divider, other.divider),
      fg: mix(fg, other.fg),
      success: mix(success, other.success),
      warning: mix(warning, other.warning),
      danger: mix(danger, other.danger),
    );
  }
}

extension AppColorsContext on BuildContext {
  /// The current theme's tokens; dark when a test theme has none.
  AppColors get colors =>
      Theme.of(this).extension<AppColors>() ?? AppColors.dark;

  /// The foreground to draw muted text, icons and tints from.
  Color get fg => colors.fg;

  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  /// A colour that only tells things apart (not a status), in a shade that
  /// reads on the current background.
  Color pick({required Color dark, required Color light}) =>
      isDark ? dark : light;
}
