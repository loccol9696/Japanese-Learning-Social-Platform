import 'package:flutter/material.dart';

import 'app_palette.dart';

class AppColors {
  AppColors._();

  // Màu chủ đạo (primary, viền focus, nút chính) lấy từ AppPalette.accent;
  // nền, thẻ, chữ lấy từ AppPalette. Các màu trang trí còn lại giữ nguyên.
  static const Color periwinkle = AppPalette.accent; // Main Primary
  static const Color softSkyBlue = Color(
    0xFF92B9E3,
  ); // Soft Sky / Secondary Blue
  static const Color warmPeach = Color(0xFFFFC4A4); // Warm Peach / Accent
  static const Color sakuraPink = Color(
    0xFFFBA2D0,
  ); // Sakura Pink / Heart / Highlight
  static const Color lavender = Color(
    0xFFC688EB,
  ); // Lavender Purple / Creative Accent
  static const Color likeRed = Color(0xFFFE2C55); // TikTok-style Like red
  static const Color saveYellow = Color(0xFFFFD700); // TikTok-style Save yellow

  // Primary & Secondary Aliases
  static const Color primary = periwinkle; // #6C7EE1
  static const Color secondary = sakuraPink; // #FBA2D0
  static const Color tertiary = softSkyBlue; // #92B9E3
  static const Color peach = warmPeach; // #FFC4A4
  static const Color purple = lavender; // #C688EB

  static const Color primaryFixed = Color(0xFFE4E8FB);
  static const Color primaryFixedDim = Color(0xFFBAC4F5);
  static const Color primaryContainer = Color(0xFF28367F);

  // Background & Surfaces (Harmonized Deep Midnight Indigo)
  static const Color background = AppPalette.background;
  static const Color backgroundCanvas = AppPalette.background;
  static const Color surface = AppPalette.surface;
  static const Color surfaceDim = AppPalette.background;
  static const Color surfaceCard = AppPalette.surface;
  static const Color surfaceCardSubtle = AppPalette.surface;
  static const Color surfaceContainer = AppPalette.surface;
  static const Color surfaceContainerLow = AppPalette.surface;
  static const Color surfaceContainerHigh = AppPalette.surface;
  static const Color surfaceContainerHighest = AppPalette.surface;
  static const Color surfaceOverlay = Color(
    0xBF0E1326,
  ); // rgba(14, 19, 38, 0.75)
  static const Color dockBackground = AppPalette.surface; // 95% opacity

  // Outlines & Borders
  static const Color outline = AppPalette.textSecondary;
  static const Color outlineVariant = AppPalette.border;
  static const Color borderGlow = AppPalette.accent;

  // Typography & On-Colors
  static const Color onSurface = AppPalette.textPrimary;
  static const Color onSurfaceVariant = AppPalette.textSecondary;
  static const Color textPrimary = AppPalette.textPrimary;
  static const Color textSecondary = AppPalette.textSecondary;
  static const Color textInverse = Color(0xFFFFFFFF);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onSecondary = Color(0xFF2B0E1E);

  // Status & Accents
  static const Color success = Color(0xFF4ADE80);
  static const Color error = Color(0xFFF87171);
}
