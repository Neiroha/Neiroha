import 'package:flutter/material.dart';

class AppTheme {
  static const accentColor = Color(0xFF7C3AED); // Deep purple accent
  static const sidebarWidth = 72.0;

  static ThemeData get dark => ThemeData(
        colorSchemeSeed: accentColor,
        useMaterial3: true,
        brightness: Brightness.dark,
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
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFF2A2A36),
          thickness: 1,
        ),
      );

  static const sidebarBg = Color(0xFF12121A);
  static const surfaceDim = Color(0xFF16161E);
  static const surfaceBright = Color(0xFF1E1E2A);
}
