import 'package:flutter/material.dart';
import 'theme_controller.dart';

class AppColors {
  AppColors._();

  static bool get isDark => ThemeController.instance.value != ThemeMode.light;

  // Brand — same across both themes for a consistent identity
  static const Color accent = Color(0xFFC026D3);
  static const Color accentDark = Color(0xFFA21CAF);

  // Backgrounds
  static Color get background =>
      isDark ? const Color(0xFF160E16) : const Color(0xFFFAF6FA);
  static Color get surface =>
      isDark ? const Color(0xFF211623) : const Color(0xFFFFFFFF);
  static Color get surfaceLight =>
      isDark ? const Color(0xFFF8EEF8) : const Color(0xFF160E16);

  // Text
  static Color get textPrimary =>
      isDark ? const Color(0xFFF7EEF7) : const Color(0xFF1A1320);
  static Color get textSecondary =>
      isDark ? const Color(0xFFA893A8) : const Color(0xFF6B5F6B);
  static const Color textDark = Color(0xFF160E16);

  // Risk levels — far from the accent hue and legible on both backgrounds
  static const Color riskLow = Color(0xFF22C55E);
  static const Color riskModerate = Color(0xFFF5A623);
  static const Color riskHigh = Color(0xFFEF4444);

  // Risk backgrounds (subtle) — dark wash in dark mode, light wash in light mode
  static Color get riskLowBg =>
      isDark ? const Color(0xFF0D2B1A) : const Color(0xFFE7F7EC);
  static Color get riskModerateBg =>
      isDark ? const Color(0xFF2B1E0A) : const Color(0xFFFDF1DE);
  static Color get riskHighBg =>
      isDark ? const Color(0xFF2E1212) : const Color(0xFFFCEAEA);

  // Utility
  static Color get divider =>
      isDark ? const Color(0xFF3A2A38) : const Color(0xFFE5DCE5);
  static Color get cardBorder =>
      isDark ? const Color(0xFF3A2A38) : const Color(0xFFE5DCE5);
}
