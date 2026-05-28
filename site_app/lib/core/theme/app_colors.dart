import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand
  static const Color navy = Color(0xFF0D1B2A);
  static const Color navyLight = Color(0xFF1A2D42);
  static const Color teal = Color(0xFF1AB5A3);
  static const Color tealDark = Color(0xFF139E8E);

  // Backgrounds
  static const Color background = navy;
  static const Color surface = navyLight;
  static const Color surfaceLight = Color(0xFFF0F4F8);

  // Text
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFF8B9EB7);
  static const Color textDark = Color(0xFF0D1B2A);

  // Risk levels
  static const Color riskLow = Color(0xFF2DC87A);
  static const Color riskModerate = Color(0xFFF5A623);
  static const Color riskHigh = Color(0xFFE8433A);

  // Risk backgrounds (subtle)
  static const Color riskLowBg = Color(0xFF0D2B1A);
  static const Color riskModerateBg = Color(0xFF2B1E0A);
  static const Color riskHighBg = Color(0xFF2B0D0D);

  // Utility
  static const Color divider = Color(0xFF1E3045);
  static const Color cardBorder = Color(0xFF1E3045);
}
