import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Colors
  static const Color surface = Color(0xFFFFF8F3);
  static const Color surfaceDim = Color(0xFFE2D8D0);
  static const Color primary = Color(0xFF7C4A2D);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color secondary = Color(0xFFE28743);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color tertiary = Color(0xFFFEE5D4);
  static const Color onTertiary = Color(0xFF7C4A2D); // Matching text for tertiary fill
  static const Color neutral = Color(0xFFF9EFE6);
  static const Color outline = Color(0xFF84746C);
  static const Color error = Color(0xFFBA1A1A);
  static const Color onError = Color(0xFFFFFFFF);

  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.plusJakartaSansTextTheme();

    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: primary,
        onPrimary: onPrimary,
        secondary: secondary,
        onSecondary: onSecondary,
        tertiary: tertiary,
        onTertiary: onTertiary,
        surface: surface,
        onSurface: Color(0xFF1F1B16),
        error: error,
        onError: onError,
        outline: outline,
      ),
      scaffoldBackgroundColor: neutral,
      textTheme: baseTextTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: primary,
        elevation: 0,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: secondary,
          foregroundColor: onSecondary,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
