import 'package:flutter/material.dart';
import '../../../../core/theme/adaptive_video_theme.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/models/video_post.dart';

/// Thông tin video ở góc dưới: chỉ hiển thị dữ liệu thật từ backend,
/// phần nào backend không trả về thì ẩn đi.
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
    final hasCreator = post.creatorTag.isNotEmpty;
    final hasJlpt = post.jlptLevel.isNotEmpty;
    final hasTitle = post.topicTag.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Creator Handle
        if (hasCreator)
          Text(
            post.creatorTag,
            style: TextStyle(
              fontSize: 16.0,
              fontWeight: FontWeight.bold,
              color: activeTheme.textPrimary,
              shadows: activeTheme.textShadows,
            ),
          ),
        if (hasCreator && (hasJlpt || hasTitle)) const SizedBox(height: 6.0),

        // JLPT Level & Video Title
        if (hasJlpt || hasTitle)
          Row(
            children: [
              // JLPT Badge (Adaptive: Đen xám on Light, Trắng on Dark)
              if (hasJlpt)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10.0,
                    vertical: 2.5,
                  ),
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
              if (hasJlpt && hasTitle) const SizedBox(width: 8.0),
              // Video title
              if (hasTitle)
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
                          maxLines: 1,
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
      ],
    );
  }
}
