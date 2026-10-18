import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Official Brand Palette (Coolors: #6C7EE1, #92B9E3, #FFC4A4, #FBA2D0, #C688EB)
  static const Color periwinkle = Color(0xFF6C7EE1); // Main Primary
  static const Color softSkyBlue = Color(0xFF92B9E3); // Soft Sky / Secondary Blue
  static const Color warmPeach = Color(0xFFFFC4A4); // Warm Peach / Accent
  static const Color sakuraPink = Color(0xFFFBA2D0); // Sakura Pink / Heart / Highlight
  static const Color lavender = Color(0xFFC688EB); // Lavender Purple / Creative Accent

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
  static const Color background = Color(0xFF0B0E1E);
  static const Color backgroundCanvas = Color(0xFF070914);
  static const Color surface = Color(0xFF0E1326);
  static const Color surfaceDim = Color(0xFF080B18);
  static const Color surfaceCard = Color(0xFF131936);
  static const Color surfaceCardSubtle = Color(0xFF171F42);
  static const Color surfaceContainer = Color(0xFF171F42);
  static const Color surfaceContainerLow = Color(0xFF101630);
  static const Color surfaceContainerHigh = Color(0xFF1C254E);
  static const Color surfaceContainerHighest = Color(0xFF232E5E);
  static const Color surfaceOverlay = Color(0xBF0E1326); // rgba(14, 19, 38, 0.75)
  static const Color dockBackground = Color(0xF2101630); // 95% opacity

  // Outlines & Borders
  static const Color outline = softSkyBlue;
  static const Color outlineVariant = Color(0xFF28346A);
  static const Color borderGlow = periwinkle;

  // Typography & On-Colors
  static const Color onSurface = Color(0xFFF4F6FD);
  static const Color onSurfaceVariant = Color(0xFFBAC4F5);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFA0AEC0);
  static const Color textInverse = Color(0xFFFFFFFF);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onSecondary = Color(0xFF2B0E1E);

  // Status & Accents
  static const Color success = Color(0xFF4ADE80);
  static const Color error = Color(0xFFF87171);

  // Dark Social Palette (TikTok-style: Profile, Flashcard)
  static const Color socialBackground = Color(0xFF121212);
  static const Color socialSurface = Color(0xFF1E1F28);
  static const Color socialCyan = Color(0xFF20D5EC);
  static const Color socialRed = Color(0xFFFE2C55);
  static const Color socialTextMuted = Color(0xFF8E8E93);
  static const Color socialDivider = Color(0xFF424242);

  // Flashcard Palette (màn bộ thẻ & các chế độ học; dùng chung socialSurface/socialTextMuted)
  static const Color flashBackground = Color(0xFF0C0E14);
  static const Color flashCardSurface = Color(0xFF161922);
  static const Color flashPanel = Color(0xFF151620); // Nhóm tùy chọn trong sheet
  static const Color flashInset = Color(0xFF111219); // Nền nút chọn chìm
  static const Color flashBorder = Color(0xFF323344);
  static const Color flashAccent = Color(0xFFFF2D55);
  static const Color flashCoral = Color(0xFFFF5A5F); // Lỗi / đang phát âm
  static const Color flashSnackBar = Color(0xFF252632);
  static const Color flashStar = Color(0xFFFFCC00);
  static const Color flashDanger = Color(0xFFEF4444);
  static const Color flashReading = Color(0xFFFF5E7E); // Cách đọc (furigana)

  // Màu nhận diện từng chế độ học (icon + nền icon)
  static const Color modeFlip = Color(0xFF4A90E2);
  static const Color modeFlipBg = Color(0xFF1E2840);
  static const Color modeQuiz = Color(0xFF00C7B1);
  static const Color modeQuizBg = Color(0xFF143034);
  static const Color modeTyping = Color(0xFF5E81F4);
  static const Color modeTypingBg = Color(0xFF1D2444);
  static const Color modeListening = Color(0xFFFF9500);
  static const Color modeListeningBg = Color(0xFF332314);
  static const Color modeMatching = Color(0xFF8B6BF6);
  static const Color modeMatchingBg = Color(0xFF282148);
}
