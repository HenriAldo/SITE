import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand
  static const Color navy = Color(0xFF0F1C2D);
  static const Color navyLight = Color(0xFF1A2D42);
  static const Color accent = Color(0xFFF43F5E);
  static const Color accentDark = Color(0xFFD6284A);

  // Backgrounds
  static const Color background = navy;
  static const Color surface = navyLight;
  static const Color surfaceLight = Color(0xFFF0F4F8);

  // Text
  static const Color textPrimary = Color(0xFFF0F4F8);
  static const Color textSecondary = Color(0xFF8B9EB7);
  static const Color textDark = Color(0xFF0F1C2D);

  // Risk levels
  static const Color riskLow = Color(0xFF2DC87A);
  static const Color riskModerate = Color(0xFFF5A623);
  static const Color riskHigh = Color(0xFFF43F5E);

  // Risk backgrounds (subtle)
  static const Color riskLowBg = Color(0xFF0D2B1A);
  static const Color riskModerateBg = Color(0xFF2B1E0A);
  static const Color riskHighBg = Color(0xFF2B0D16);

  // Utility
  static const Color divider = Color(0xFF1E3045);
  static const Color cardBorder = Color(0xFF1E3045);
}
