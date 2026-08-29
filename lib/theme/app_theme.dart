import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const Color primary = Color(0xFFBB86FC);
  static const Color onPrimary = Color(0xFF000000);
  static const Color primaryContainer = Color(0xFF1A1025);
  static const Color secondary = Color(0xFF03DAC5);
  static const Color background = Color(0xFF0C0C0F);
  static const Color surface = Color(0xFF141418);
  static const Color surfaceVariant = Color(0xFF1C1C22);
  static const Color surfaceContainerHigh = Color(0xFF28282F);
  static const Color outline = Color(0xFF3A3A42);
  static const Color error = Color(0xFFFFB4AB);
  static const Color muted = Color(0xFF8A8A8E);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        onPrimary: onPrimary,
        primaryContainer: primaryContainer,
        secondary: secondary,
        surface: surface,
        error: error,
        outline: outline,
      ),
      scaffoldBackgroundColor: background,
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: false,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfaceContainerHigh,
        selectedItemColor: primary,
        unselectedItemColor: muted,
      ),
      inputDecorationTheme: InputDecorationTheme(
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: outline),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: primary, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: surfaceVariant,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: outline),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceVariant,
        selectedColor: secondary.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
