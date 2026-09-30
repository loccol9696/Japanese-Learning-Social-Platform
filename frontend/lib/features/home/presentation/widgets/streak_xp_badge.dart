import 'package:flutter/material.dart';
import '../../../../core/localization/locale_manager.dart';
import '../../../../core/theme/adaptive_video_theme.dart';
import '../../../../core/theme/app_colors.dart';

class StreakXpBadge extends StatelessWidget {
  final int streakDays;
  final int xp;
  final AdaptiveVideoTheme? theme;

  const StreakXpBadge({
    super.key,
    required this.streakDays,
    required this.xp,
    this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final activeTheme = theme ?? const AdaptiveVideoTheme(isLight: false);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: activeTheme.streakBadgeBackground,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(color: activeTheme.streakBadgeBorder, width: 1.0),
        boxShadow: activeTheme.cardShadows,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('⚡', style: TextStyle(fontSize: 14.0)),
          const SizedBox(width: 4.0),
          Text(
            appStrings.dayStreak(streakDays),
            style: TextStyle(
              fontSize: 12.0,
              fontWeight: FontWeight.bold,
              color: activeTheme.streakBadgeText,
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 6.0),
            width: 4.0,
            height: 4.0,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: activeTheme.isLight
                  ? const Color(0xFF1E212D).withValues(alpha: 0.4)
                  : AppColors.softSkyBlue.withValues(alpha: 0.7),
            ),
          ),
          Text(
            appStrings.xpEarned(xp),
            style: TextStyle(
              fontSize: 12.0,
              fontWeight: FontWeight.bold,
              color: activeTheme.isLight
                  ? const Color(0xFFD97706)
                  : AppColors.warmPeach,
            ),
          ),
        ],
      ),
    );
  }
}
