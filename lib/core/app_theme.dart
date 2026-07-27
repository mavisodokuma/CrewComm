import 'package:flutter/material.dart';

class AppTheme {
  static const background = Color(0xFF121212);
  static const panel = Color(0xFF1B1D1F);
  static const panelAlt = Color(0xFF24272A);
  static const green = Color(0xFF2CFF8F);
  static const red = Color(0xFFFF3045);
  static const yellow = Color(0xFFFFC83D);
  static const text = Color(0xFFF2F5F7);
  static const muted = Color(0xFF8B949E);

  static ThemeData dark() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: green,
        secondary: yellow,
        error: red,
        surface: panel,
      ),
      useMaterial3: true,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: text,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardTheme(
        color: panel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected) ? green : muted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? green.withOpacity(0.25)
              : muted.withOpacity(0.2);
        }),
      ),
    );
  }
}
