import 'package:flutter/material.dart';
import '../../../../core/localization/locale_manager.dart';
import '../../../../core/theme/adaptive_video_theme.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/count_format.dart';
import '../../domain/models/video_post.dart';

/// Thông tin video ở góc dưới: người đăng + trình độ, tiêu đề, lượt xem + âm thanh.
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
    final secondaryStyle = TextStyle(
      fontSize: 12.0,
      fontWeight: FontWeight.w500,
      color: activeTheme.textSecondary,
      shadows: activeTheme.textShadows,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Người đăng + trình độ JLPT
        Row(
          children: [
            Flexible(
              child: Text(
                post.creatorTag,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16.0,
                  fontWeight: FontWeight.bold,
                  color: activeTheme.textPrimary,
                  shadows: activeTheme.textShadows,
                ),
              ),
            ),
            const SizedBox(width: 8.0),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
              decoration: BoxDecoration(
                color: activeTheme.jlptBadgeBackground,
                borderRadius: BorderRadius.circular(10.0),
              ),
              child: Text(
                post.jlptLevel,
                style: TextStyle(
                  fontSize: 11.0,
                  fontWeight: FontWeight.bold,
                  color: activeTheme.jlptBadgeText,
                ),
              ),
            ),
          ],
        ),

        // 2. Tiêu đề (hiển thị một lần, tối đa 2 dòng)
        if (post.topicTag.isNotEmpty) ...[
          const SizedBox(height: 6.0),
          Text(
            post.topicTag,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14.0,
              height: 1.3,
              fontWeight: FontWeight.w500,
              color: activeTheme.textPrimary,
              shadows: activeTheme.textShadows,
            ),
          ),
        ],
        const SizedBox(height: 8.0),

        // 3. Lượt xem + âm thanh gốc
        Row(
          children: [
            Icon(
              Icons.play_arrow_rounded,
              size: 15.0,
              color: activeTheme.textSecondary,
              shadows: activeTheme.textShadows,
            ),
            const SizedBox(width: 2.0),
            Text(appStrings.homeViews(formatCount(post.viewCount)), style: secondaryStyle),
            const SizedBox(width: 12.0),
            Icon(
              Icons.music_note_rounded,
              size: 14.0,
              color: activeTheme.isLight ? const Color(0xFF7C3AED) : AppColors.lavender,
            ),
            const SizedBox(width: 3.0),
            Expanded(
              child: Text(
                appStrings.homeOriginalSound(post.audioTitle),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: secondaryStyle,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
