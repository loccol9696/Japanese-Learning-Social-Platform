import 'package:flutter/material.dart';
import '../../../../core/theme/adaptive_video_theme.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/models/video_post.dart';

class VideoInfoOverlay extends StatelessWidget {
  final VideoPost post;
  final AdaptiveVideoTheme? theme;

  const VideoInfoOverlay({
    super.key,
    required this.post,
    this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final activeTheme = theme ?? const AdaptiveVideoTheme(isLight: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Creator Handle & Verified Accent Badge
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8.0,
          runSpacing: 4.0,
          children: [
            Text(
              post.creatorTag,
              style: TextStyle(
                fontSize: 16.0,
                fontWeight: FontWeight.bold,
                color: activeTheme.textPrimary,
                shadows: activeTheme.textShadows,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
              decoration: BoxDecoration(
                color: activeTheme.isLight
                    ? Colors.white.withValues(alpha: 0.8)
                    : AppColors.periwinkle.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12.0),
                border: Border.all(
                  color: activeTheme.isLight
                      ? const Color(0xFF1E212D).withValues(alpha: 0.2)
                      : AppColors.softSkyBlue.withValues(alpha: 0.5),
                  width: 1.0,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.verified_rounded,
                    size: 14.0,
                    color: activeTheme.isLight
                        ? const Color(0xFF1E212D)
                        : AppColors.softSkyBlue,
                  ),
                  const SizedBox(width: 4.0),
                  Text(
                    post.accentInfo,
                    style: TextStyle(
                      fontSize: 11.0,
                      fontWeight: FontWeight.w600,
                      color: activeTheme.isLight
                          ? const Color(0xFF1E212D)
                          : AppColors.primaryFixed,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6.0),

        // JLPT Level & Topic Pill
        Row(
          children: [
            // JLPT Badge (Adaptive: Đen xám on Light, Trắng on Dark)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 2.5),
              decoration: BoxDecoration(
                color: activeTheme.jlptBadgeBackground,
                borderRadius: BorderRadius.circular(12.0),
                boxShadow: [
                  BoxShadow(
                    color: activeTheme.isLight
                        ? Colors.black.withValues(alpha: 0.15)
                        : Colors.white.withValues(alpha: 0.25),
                    blurRadius: 8.0,
                  ),
                ],
              ),
              child: Text(
                post.jlptLevel,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: activeTheme.jlptBadgeText,
                ),
              ),
            ),
            const SizedBox(width: 8.0),
            // Topic with Cafe Icon
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.local_cafe_rounded,
                    size: 14.0,
                    color: activeTheme.isLight
                        ? const Color(0xFFD97706)
                        : AppColors.warmPeach,
                  ),
                  const SizedBox(width: 4.0),
                  Flexible(
                    child: Text(
                      post.topicTag,
                      style: TextStyle(
                        fontSize: 12.0,
                        fontWeight: FontWeight.w600,
                        color: activeTheme.textSecondary,
                        overflow: TextOverflow.ellipsis,
                        shadows: activeTheme.textShadows,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6.0),

        // Audio Info Footer with Music Note
        Row(
          children: [
            Icon(
              Icons.music_note_rounded,
              size: 14.0,
              color: activeTheme.isLight
                  ? const Color(0xFF7C3AED)
                  : AppColors.lavender,
            ),
            const SizedBox(width: 4.0),
            Expanded(
              child: Text(
                post.audioTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.0,
                  fontWeight: FontWeight.w500,
                  color: activeTheme.textSecondary,
                  shadows: activeTheme.textShadows,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
