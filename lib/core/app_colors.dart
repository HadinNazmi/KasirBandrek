import 'package:flutter/material.dart';

/// Palet warna terpusat untuk aplikasi Kedai Bandrek POS
/// Berdasarkan palet resmi client:
/// - Cream: #F2E8D8
/// - Gold: #C9A46D
/// - Burgundy: #8B1E2D
/// - Burgundy Dark: #5B0F1A
/// - Burgundy Deep: #2D070D
class AppColors {
  AppColors._();

  // =========================================================================
  // 5 Warna Inti Palet Klien
  // =========================================================================
  static const Color cream = Color(0xFFF2E8D8);
  static const Color gold = Color(0xFFC9A46D);
  static const Color burgundy = Color(0xFF8B1E2D);
  static const Color burgundyDark = Color(0xFF5B0F1A);
  static const Color burgundyDeep = Color(0xFF2D070D);

  // =========================================================================
  // Variasi Latar & Permukaan (Cream tones)
  // =========================================================================
  /// Latar belakang aplikasi / scaffold (#F2E8D8)
  static const Color background = cream;
  static const Color scaffoldBg = cream;

  /// Latar kartu & modal terang (variasi krem terang #FAF5EE untuk membedakan dengan scaffold)
  static const Color surface = Color(0xFFFAF5EE);
  static const Color cardBg = Color(0xFFFAF5EE);
  static const Color cardSurfaceLight = Color(0xFFFAF5EE);

  /// Latar kontainer bertingkat / input / chip tidak aktif
  static const Color surfaceElevated = Color(0xFFFAF5EE);
  static const Color cardBgSecondary = Color(0xFFEBDDC8);
  static const Color surfaceDim = Color(0xFFE8DBC6);
  static const Color disabledBg = Color(0x1F2D070D);

  // =========================================================================
  // Tipografi & Ikon (Berdasarkan rasio kontras WCAG)
  // =========================================================================
  /// Teks utama & ikon utama di atas latar terang (#2D070D)
  static const Color textPrimary = burgundyDeep;
  static const Color textDark = burgundyDeep;

  /// Teks sekunder / keterangan di atas latar terang (turunan 65% opacity #2D070D)
  static const Color textSecondary = Color(0xA62D070D);

  /// Teks tersier / placeholder / disabled (turunan 38% opacity #2D070D)
  static const Color textMuted = Color(0x612D070D);
  static const Color textDisabled = Color(0x612D070D);

  /// Teks di atas latar gelap (Burgundy, BurgundyDark, BurgundyDeep)
  static const Color textOnDark = cream;

  /// Teks redup di atas latar gelap
  static const Color textOnDarkMuted = Color(0xBFFAF5EE);

  /// Teks di atas latar emas (#2D070D)
  static const Color textOnGold = burgundyDeep;

  // =========================================================================
  // Aksen Merek & Elemen Aktif
  // =========================================================================
  /// Tombol utama, chip terpilih, elemen aktif (#8B1E2D)
  static const Color primary = burgundy;

  /// App bar, bottom navigation, header gelap (#5B0F1A)
  static const Color appBarBg = burgundyDark;
  static const Color bottomNavBg = burgundyDark;

  /// Aksen badge, sorotan, progress bar, border aktif (#C9A46D)
  static const Color accent = gold;

  /// Latar tint aksen emas lembut
  static const Color goldTint = Color(0xFFF7EEDF);

  // =========================================================================
  // Border, Divider, & Shadow (Turunan palet #2D070D dengan opasitas)
  // =========================================================================
  /// Garis pemisah tipis (~12% opasitas)
  static const Color divider = Color(0x1F2D070D);

  /// Border kontainer & card (~16% opasitas)
  static const Color border = Color(0x292D070D);

  /// Border fokus / aktif (~35% opasitas)
  static const Color borderFocused = Color(0x592D070D);

  /// Bayangan halus
  static const Color shadow = Color(0x1A2D070D);
  static const Color shadowColor = Color(0x1A2D070D);
  static const Color shadowDark = Color(0x262D070D);

  // =========================================================================
  // Warna Semantik Status (Terpisah dari palet merek)
  // =========================================================================
  /// Status Batal / Error / Delete: Merah cerah (jelas berbeda dari burgundy)
  static const Color error = Color(0xFFD32F2F);
  static const Color errorBg = Color(0xFFFFEBEE);
  static const Color errorBorder = Color(0xFFEF9A9A);

  /// Status Sukses / Selesai / Online: Hijau
  static const Color success = Color(0xFF2E7D32);
  static const Color successBg = Color(0xFFE8F5E9);
  static const Color successBorder = Color(0xFFA5D6A7);

  /// Status Peringatan / Offline sync: Oranye
  static const Color warning = Color(0xFFED6C02);
  static const Color warningBg = Color(0xFFFFF3E0);
  static const Color warningBorder = Color(0xFFFFCC80);

  /// Status Info / Sistem: Biru
  static const Color info = Color(0xFF1976D2);
  static const Color infoBg = Color(0xFFE3F2FD);
  static const Color infoBorder = Color(0xFF90CAF9);
}
