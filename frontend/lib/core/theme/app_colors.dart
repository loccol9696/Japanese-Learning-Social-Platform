import 'package:flutter/material.dart';

import 'app_palette.dart';

/// Tên màu theo ngữ nghĩa Material, dùng trong UI. Màu phụ thuộc theme (nền,
/// thẻ, chữ, viền, trạng thái) đều là getter đọc từ [AppPalette]; chỉ các màu
/// trang trí không đổi theo theme mới là hằng số.
class AppColors {
  AppColors._();

  // ---- Màu trang trí: giữ nguyên ở cả hai chế độ ----
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

  // Màu thương hiệu bên thứ ba (VNPay): cố định, không đổi theo theme.
  static const Color vnpayBlue = Color(0xFF005BAA);
  static const Color vnpayBlueLight = Color(0xFF0072CE);

  // ---- Màu chủ đạo (theo theme) ----
  static Color get periwinkle => AppPalette.accent; // Main Primary
  static Color get primary => AppPalette.accent;
  static const Color secondary = sakuraPink;
  static const Color tertiary = softSkyBlue;
  static const Color peach = warmPeach;
  static const Color purple = lavender;

  static Color get primaryFixed => AppPalette.accentSoft;
  static Color get primaryFixedDim => AppPalette.accentSoft;
  static Color get primaryContainer => AppPalette.accentSoft;

  // ---- Nền & bề mặt ----
  static Color get background => AppPalette.background;
  static Color get backgroundCanvas => AppPalette.background;
  static Color get surface => AppPalette.surface;
  static Color get surfaceDim => AppPalette.background;
  static Color get surfaceCard => AppPalette.surface;
  static Color get surfaceCardSubtle => AppPalette.surface;
  static Color get surfaceContainer => AppPalette.surface;
  static Color get surfaceContainerLow => AppPalette.surface;
  static Color get surfaceContainerHigh => AppPalette.surfaceHigh;
  static Color get surfaceContainerHighest => AppPalette.surfaceHighest;
  static Color get surfaceOverlay => AppPalette.scrim;
  static Color get dockBackground => AppPalette.surface;

  // ---- Viền ----
  static Color get outline => AppPalette.textSecondary;
  static Color get outlineVariant => AppPalette.border;
  static Color get borderGlow => AppPalette.accent;

  // ---- Chữ & màu "on" ----
  static Color get onSurface => AppPalette.textPrimary;
  static Color get onSurfaceVariant => AppPalette.textSecondary;
  static Color get textPrimary => AppPalette.textPrimary;
  static Color get textSecondary => AppPalette.textSecondary;
  static Color get textInverse => AppPalette.background;
  static Color get onPrimary => AppPalette.onAccent;
  static const Color onSecondary = Color(0xFF2B0E1E);

  // ---- Trạng thái ----
  static Color get success => AppPalette.success;
  static Color get error => AppPalette.error;
}
