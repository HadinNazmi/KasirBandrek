import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  // Aliases for compatibility
  static const Color surface = AppColors.surface;
  static const Color surfaceDim = AppColors.surfaceDim;
  static const Color primary = AppColors.burgundy;
  static const Color onPrimary = AppColors.cream;
  static const Color secondary = AppColors.gold;
  static const Color onSecondary = AppColors.burgundyDeep;
  static const Color tertiary = AppColors.goldTint;
  static const Color onTertiary = AppColors.burgundyDeep;
  static const Color neutral = AppColors.cream;
  static const Color outline = AppColors.border;
  static const Color error = AppColors.error;
  static const Color onError = AppColors.cream;

  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.plusJakartaSansTextTheme();

    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: AppColors.burgundy,
        onPrimary: AppColors.cream,
        secondary: AppColors.gold,
        onSecondary: AppColors.burgundyDeep,
        tertiary: AppColors.goldTint,
        onTertiary: AppColors.burgundyDeep,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        error: AppColors.error,
        onError: AppColors.cream,
        outline: AppColors.border,
      ),
      scaffoldBackgroundColor: AppColors.background,
      textTheme: baseTextTheme.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.appBarBg,
        foregroundColor: AppColors.cream,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppColors.cream),
        titleTextStyle: TextStyle(
          color: AppColors.cream,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.burgundy,
          foregroundColor: AppColors.cream,
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.burgundy,
          side: const BorderSide(color: AppColors.burgundy),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.bottomNavBg,
        selectedItemColor: AppColors.gold,
        unselectedItemColor: AppColors.textOnDarkMuted,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
      ),
    );
  }
}
