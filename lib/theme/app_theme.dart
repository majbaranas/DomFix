import 'package:flutter/material.dart';

import 'app_spacing.dart';

class AppTheme {
  // Dark Theme Colors
  static const _darkBackground = Color(0xFF070B14);
  static const _darkSurface = Color(0xFF101419);
  static const _darkPrimary = Color(0xFFCDF200); // Or Neon Accent: 0xFFD9FF00
  static const _darkPrimaryText = Color(0xFFE0E2EA);

  // Light Theme Colors
  static const _lightBackground = Color(0xFFF8FAFC);
  static const _lightSurface = Color(0xFFFFFFFF);
  static const _lightPrimary = Color(0xFFD9FF00); // Restored original DomFix neon
  static const _lightPrimaryText = Color(0xFF0F172A);

  static ThemeData get darkTheme {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: _darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: _darkPrimary,
        secondary: Color(0xFF00B8FF), // Secondary Accent
        surface: _darkSurface,
        onSurface: _darkPrimaryText,
        error: Color(0xFFFFB4AB),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData.light().copyWith(
      scaffoldBackgroundColor: _lightBackground,
      colorScheme: const ColorScheme.light(
        primary: _lightPrimary,
        secondary: Color(0xFF00B8FF),
        surface: _lightSurface,
        onSurface: _lightPrimaryText,
        error: Color(0xFFEF4444),
      ),
    );
  }
}
