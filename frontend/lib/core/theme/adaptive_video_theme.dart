import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_palette.dart';

/// Defines adaptive UI colors based on the underlying video brightness.
/// - If [isLight] == true (nền video sáng / trắng): UI chuyển sang ĐEN XÁM.
/// - If [isLight] == false (nền video tối / đen): UI chuyển sang TRẮNG.
class AdaptiveVideoTheme {
  final bool isLight;

  const AdaptiveVideoTheme({required this.isLight});

  // 1. Màu tương phản chủ đạo (User: Nền trắng -> Đen xám, Nền đen -> Trắng)
  Color get primaryAdaptive => isLight ? AppPalette.videoScrim : AppPalette.onVideo;

  // Text chính & thứ cấp
  Color get textPrimary => isLight ? AppPalette.videoScrim : AppPalette.onVideo;
  Color get textSecondary =>
      isLight ? AppPalette.videoScrim.withValues(alpha: 0.75) : AppPalette.onVideoMuted;

  // Badge JLPT
  Color get jlptBadgeBackground =>
      isLight ? AppPalette.videoScrim : AppPalette.onVideo;
  Color get jlptBadgeText => isLight ? AppPalette.onVideo : AppPalette.videoScrim;

  // Thanh tiến trình video (Scrubber)
  Color get progressActive => isLight ? AppPalette.videoScrim : AppPalette.onVideo;
  Color get progressTrack => isLight
      ? AppPalette.videoScrim.withValues(alpha: 0.18)
      : AppPalette.onVideo.withValues(alpha: 0.22);
  Color get progressGlow => isLight
      ? AppPalette.videoScrim.withValues(alpha: 0.4)
      : AppPalette.onVideo.withValues(alpha: 0.7);

  // Hiệu ứng Play/Pause Ripple
  Color get playRippleBorder =>
      isLight ? AppPalette.videoScrim : AppPalette.onVideo;
  Color get playRippleIcon => isLight ? AppPalette.videoScrim : AppPalette.onVideo;
  Color get playRippleBackground => isLight
      ? AppPalette.onVideo.withValues(alpha: 0.8)
      : AppPalette.videoScrim.withValues(alpha: 0.75);

  // Nút hành động tương tác (Sidebar: Like, Comment, Share)
  Color get actionButtonBackground => isLight
      ? AppPalette.onVideo.withValues(alpha: 0.82)
      : AppPalette.videoScrim.withValues(alpha: 0.72);
  Color get actionButtonBorder => isLight
      ? AppPalette.videoScrim.withValues(alpha: 0.18)
      : AppPalette.onVideo.withValues(alpha: 0.25);
  Color get actionButtonIcon =>
      isLight ? AppPalette.videoScrim : AppPalette.onVideo;
  Color get actionCountText => isLight ? AppPalette.videoScrim : AppPalette.onVideo;

  // Subtitle card (Phụ đề Ruby)
  Color get subtitleCardBackground => isLight
      ? AppPalette.onVideo.withValues(alpha: 0.90)
      : AppPalette.videoScrim.withValues(alpha: 0.90);
  Color get subtitleCardBorder => isLight
      ? AppPalette.videoScrim.withValues(alpha: 0.18)
      : AppColors.periwinkle.withValues(alpha: 0.4);
  Color get kanjiTextColor => isLight ? AppPalette.videoScrim : AppPalette.onVideo;
  Color get furiganaColor =>
      isLight ? AppPalette.warning : AppColors.warmPeach;
  Color get translationCardBackground => isLight
      ? AppPalette.onVideo.withValues(alpha: 0.85)
      : AppPalette.videoScrim.withValues(alpha: 0.88);
  Color get translationTextColor =>
      isLight ? AppPalette.videoScrim.withValues(alpha: 0.75) : AppPalette.onVideo;
  Color get ttsButtonBackground => isLight
      ? AppPalette.videoScrim.withValues(alpha: 0.10)
      : AppColors.periwinkle.withValues(alpha: 0.25);
  Color get ttsButtonIcon =>
      isLight ? AppPalette.videoScrim : AppPalette.onVideoMuted;

  // Scrim gradients phủ trên và dưới video
  List<Color> get topScrimColors => isLight
      ? [
          AppPalette.onVideo.withValues(alpha: 0.88),
          AppPalette.onVideo.withValues(alpha: 0.40),
          Colors.transparent,
        ]
      : [
          AppPalette.videoScrim.withValues(alpha: 0.85),
          AppPalette.videoScrim.withValues(alpha: 0.40),
          Colors.transparent,
        ];

  List<Color> get bottomScrimColors => [
        AppPalette.videoScrim.withValues(alpha: 0.87),
        AppPalette.videoScrim.withValues(alpha: 0.60),
        AppPalette.videoScrim.withValues(alpha: 0.20),
        Colors.transparent,
      ];

  // Header switcher
  Color get headerSelectedText =>
      isLight ? AppPalette.videoScrim : AppPalette.onVideo;
  Color get headerUnselectedText => isLight
      ? AppPalette.videoScrim.withValues(alpha: 0.55)
      : AppPalette.onVideo.withValues(alpha: 0.65);
  Color get headerIndicator => isLight ? AppPalette.videoScrim : AppPalette.onVideo;
  Color get headerSearchIcon =>
      isLight ? AppPalette.videoScrim : AppPalette.onVideo;

  // Streak & XP pill
  Color get streakBadgeBackground => isLight
      ? AppPalette.onVideo.withValues(alpha: 0.90)
      : AppPalette.videoScrim.withValues(alpha: 0.88);
  Color get streakBadgeBorder => isLight
      ? AppPalette.videoScrim.withValues(alpha: 0.18)
      : AppPalette.onVideo.withValues(alpha: 0.25);
  Color get streakBadgeText => isLight ? AppPalette.videoScrim : AppPalette.onVideo;

  // Drop Shadows
  List<Shadow> get textShadows => isLight
      ? [
          Shadow(
            color: AppPalette.onVideo,
            blurRadius: 4.0,
          ),
        ]
      : [
          Shadow(
            color: AppPalette.videoScrim.withValues(alpha: 0.87),
            blurRadius: 4.0,
          ),
        ];

  List<BoxShadow> get cardShadows => isLight
      ? [
          BoxShadow(
            color: AppPalette.shadow,
            blurRadius: 16.0,
            offset: const Offset(0, 4),
          ),
        ]
      : [
          BoxShadow(
            color: AppPalette.shadow,
            blurRadius: 20.0,
            offset: const Offset(0, 8),
          ),
        ];
}
