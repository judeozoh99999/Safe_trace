import 'package:flutter/material.dart';

class AppColors {
  // App Color Palette
  static const Color primary = Color(0xFFEB444E); // Coral Red
  static const Color backgroundDark = Color(0xFF131522); // Dark Navy Background
  static const Color backgroundLight = Color(0xFFF8F9FB); // Off-white Background
  static const Color white = Colors.white;
  static const Color black = Colors.black;

  // Text Colors
  static const Color textDarkPrimary = Colors.white;
  static const Color textDarkSecondary = Color(0xFF8A8F9E); // Muted Greyish-Blue
  static const Color textLightPrimary = Color(0xFF131522); // Dark Navy Text
  static const Color textLightSecondary = Color(0xFF5D6273); // Muted Grey Text

  // Interactive Elements
  static const Color buttonDark = Color(0xFF1A1C2E);
  static const Color buttonLight = Color(0xFF131522);
  static const Color buttonMuted = Color(0xFF2B2E4A);

  // Cards and Containers
  static const Color cardDark = Color(0xFF1C1E2D);
  static const Color cardLight = Colors.white;
  static const Color dividerDark = Color(0xFF282B40);
  static const Color dividerLight = Color(0xFFEBEFF5);

  // Status Colors
  static const Color success = Color(0xFF2EC4B6);
  static const Color warning = Color(0xFFFF9F1C);
  static const Color error = Color(0xFFE63946);
  static const Color info = Color(0xFF4A90E2);

  // Emergency Contact Avatar Colors
  static const Color avatarPurple = Color(0xFF8C52FF);
  static const Color avatarGreen = Color(0xFF28A745);
  static const Color avatarNavy = Color(0xFF1D3557);
  static const Color avatarOrange = Color(0xFFE68A00);
  static const Color avatarRed = Color(0xFFDC3545);

  static const List<Color> avatarColors = [
    avatarPurple,
    avatarGreen,
    avatarNavy,
    avatarOrange,
    avatarRed,
  ];
}

extension ThemeColors on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
  Color get scaffoldBg => isDarkMode ? AppColors.backgroundDark : const Color(0xFFF9FAFB);
  Color get cardBg => isDarkMode ? AppColors.cardDark : Colors.white;
  Color get border => isDarkMode ? AppColors.dividerDark : const Color(0xFFE5E7EB);
  Color get textPrimary => isDarkMode ? Colors.white : const Color(0xFF111827);
  Color get textSecondary => isDarkMode ? AppColors.textDarkSecondary : const Color(0xFF6B7280);
}
