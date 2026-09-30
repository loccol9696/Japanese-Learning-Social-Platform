import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Defines adaptive UI colors based on the underlying video brightness.
/// - If [isLight] == true (nền video sáng / trắng): UI chuyển sang ĐEN XÁM.
/// - If [isLight] == false (nền video tối / đen): UI chuyển sang TRẮNG.
class AdaptiveVideoTheme {
  final bool isLight;

  const AdaptiveVideoTheme({required this.isLight});

  // 1. Màu tương phản chủ đạo (User: Nền trắng -> Đen xám, Nền đen -> Trắng)
  Color get primaryAdaptive => isLight ? const Color(0xFF1E212D) : Colors.white;

  // Text chính & thứ cấp
  Color get textPrimary => isLight ? const Color(0xFF0F172A) : Colors.white;
  Color get textSecondary =>
      isLight ? const Color(0xFF475569) : const Color(0xFFCBD5E1);

  // Badge JLPT
  Color get jlptBadgeBackground =>
      isLight ? const Color(0xFF1E212D) : Colors.white;
  Color get jlptBadgeText => isLight ? Colors.white : const Color(0xFF0B0E1E);

  // Thanh tiến trình video (Scrubber)
  Color get progressActive => isLight ? const Color(0xFF1E212D) : Colors.white;
  Color get progressTrack => isLight
      ? const Color(0xFF1E212D).withValues(alpha: 0.18)
      : Colors.white.withValues(alpha: 0.22);
  Color get progressGlow => isLight
      ? const Color(0xFF1E212D).withValues(alpha: 0.4)
      : Colors.white.withValues(alpha: 0.7);

  // Hiệu ứng Play/Pause Ripple
  Color get playRippleBorder =>
      isLight ? const Color(0xFF1E212D) : Colors.white;
  Color get playRippleIcon => isLight ? const Color(0xFF1E212D) : Colors.white;
  Color get playRippleBackground => isLight
      ? Colors.white.withValues(alpha: 0.8)
      : const Color(0xFF0E1326).withValues(alpha: 0.75);

  // Nút hành động tương tác (Sidebar: Like, Comment, Share)
  Color get actionButtonBackground => isLight
      ? Colors.white.withValues(alpha: 0.82)
      : const Color(0xFF0E1326).withValues(alpha: 0.72);
  Color get actionButtonBorder => isLight
      ? const Color(0xFF1E212D).withValues(alpha: 0.18)
      : Colors.white.withValues(alpha: 0.25);
  Color get actionButtonIcon =>
      isLight ? const Color(0xFF1E212D) : Colors.white;
  Color get actionCountText => isLight ? const Color(0xFF1E212D) : Colors.white;

  // Subtitle card (Phụ đề Ruby)
  Color get subtitleCardBackground => isLight
      ? Colors.white.withValues(alpha: 0.90)
      : const Color(0xFF101630).withValues(alpha: 0.90);
  Color get subtitleCardBorder => isLight
      ? const Color(0xFF1E212D).withValues(alpha: 0.18)
      : AppColors.periwinkle.withValues(alpha: 0.4);
  Color get kanjiTextColor => isLight ? const Color(0xFF0F172A) : Colors.white;
  Color get furiganaColor =>
      isLight ? const Color(0xFFD97706) : AppColors.warmPeach;
  Color get translationCardBackground => isLight
      ? Colors.white.withValues(alpha: 0.85)
      : const Color(0xFF101630).withValues(alpha: 0.88);
  Color get translationTextColor =>
      isLight ? const Color(0xFF334155) : const Color(0xFFF4F6FD);
  Color get ttsButtonBackground => isLight
      ? const Color(0xFF1E212D).withValues(alpha: 0.10)
      : AppColors.periwinkle.withValues(alpha: 0.25);
  Color get ttsButtonIcon =>
      isLight ? const Color(0xFF1E212D) : AppColors.onSurfaceVariant;

  // Scrim gradients phủ trên và dưới video
  List<Color> get topScrimColors => isLight
      ? [
          Colors.white.withValues(alpha: 0.88),
          Colors.white.withValues(alpha: 0.40),
          Colors.transparent,
        ]
      : [
          const Color(0xFF080B18).withValues(alpha: 0.85),
          const Color(0xFF080B18).withValues(alpha: 0.40),
          Colors.transparent,
        ];

  List<Color> get bottomScrimColors => isLight
      ? [
          Colors.white.withValues(alpha: 0.95),
          Colors.white.withValues(alpha: 0.60),
          Colors.transparent,
        ]
      : [
          const Color(0xFF080B18).withValues(alpha: 0.95),
          const Color(0xFF080B18).withValues(alpha: 0.75),
          Colors.transparent,
        ];

  // Header switcher
  Color get headerSelectedText =>
      isLight ? const Color(0xFF0F172A) : Colors.white;
  Color get headerUnselectedText => isLight
      ? const Color(0xFF0F172A).withValues(alpha: 0.55)
      : Colors.white.withValues(alpha: 0.65);
  Color get headerIndicator => isLight ? const Color(0xFF1E212D) : Colors.white;
  Color get headerSearchIcon =>
      isLight ? const Color(0xFF0F172A) : Colors.white;

  // Streak & XP pill
  Color get streakBadgeBackground => isLight
      ? Colors.white.withValues(alpha: 0.90)
      : const Color(0xFF0E1326).withValues(alpha: 0.88);
  Color get streakBadgeBorder => isLight
      ? const Color(0xFF1E212D).withValues(alpha: 0.18)
      : Colors.white.withValues(alpha: 0.25);
  Color get streakBadgeText => isLight ? const Color(0xFF0F172A) : Colors.white;

  // Drop Shadows
  List<Shadow> get textShadows => isLight
      ? [
          const Shadow(
            color: Colors.white,
            blurRadius: 4.0,
          ),
        ]
      : [
          const Shadow(
            color: Colors.black87,
            blurRadius: 4.0,
          ),
        ];

  List<BoxShadow> get cardShadows => isLight
      ? [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16.0,
            offset: const Offset(0, 4),
          ),
        ]
      : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20.0,
            offset: const Offset(0, 8),
          ),
        ];
}
