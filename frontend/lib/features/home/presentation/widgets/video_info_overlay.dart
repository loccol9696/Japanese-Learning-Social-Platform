import 'package:flutter/material.dart';
import '../../../../core/theme/adaptive_video_theme.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/models/video_post.dart';
import '../../../../core/theme/app_palette.dart';

/// Thông tin video ở góc dưới: gom nhóm @username và Badge JLPT gọn gàng bên dưới phần script
class VideoInfoOverlay extends StatelessWidget {
  final VideoPost post;
  final AdaptiveVideoTheme? theme;

  /// Bấm vào @username để mở trang cá nhân người đăng.
  final VoidCallback? onCreatorTap;

  const VideoInfoOverlay({
    super.key,
    required this.post,
    this.theme,
    this.onCreatorTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeTheme = theme ?? const AdaptiveVideoTheme(isLight: false);
    final hasCreator = post.creatorTag.isNotEmpty;
    final hasJlpt = post.jlptLevel.isNotEmpty;
    final hasTitle = post.topicTag.isNotEmpty;

    if (!hasCreator && !hasJlpt && !hasTitle) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Gom nhóm @username và Badge JLPT gọn gàng trên cùng 1 hàng
        if (hasCreator || hasJlpt)
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (hasCreator)
                Flexible(
                  child: GestureDetector(
                    onTap: onCreatorTap,
                    behavior: HitTestBehavior.opaque,
                    child: Text(
                      post.creatorTag,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15.0,
                        fontWeight: FontWeight.bold,
                        color: AppPalette.onVideo,
                        shadows: [
                          Shadow(
                            color: AppPalette.videoScrim.withValues(
                              alpha: 0.60,
                            ),
                            offset: Offset(0, 1),
                            blurRadius: 4.0,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (hasCreator && hasJlpt) const SizedBox(width: 8.0),
              if (hasJlpt)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 2.0,
                  ),
                  decoration: BoxDecoration(
                    color: activeTheme.jlptBadgeBackground,
                    borderRadius: BorderRadius.circular(10.0),
                    boxShadow: [
                      BoxShadow(
                        color: AppPalette.videoScrim.withValues(alpha: 0.25),
                        blurRadius: 4.0,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Text(
                    post.jlptLevel,
                    style: TextStyle(
                      fontSize: 11.0,
                      fontWeight: FontWeight.bold,
                      color: activeTheme.jlptBadgeText,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
            ],
          ),

        // Video title / topic tag nếu có
        if (hasTitle) ...[
          const SizedBox(height: 5.0),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.local_cafe_rounded,
                size: 13.0,
                color: activeTheme.isLight
                    ? AppPalette.warning
                    : AppColors.warmPeach,
              ),
              const SizedBox(width: 4.0),
              Flexible(
                child: Text(
                  post.topicTag,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.0,
                    fontWeight: FontWeight.w500,
                    color: AppPalette.onVideo.withValues(alpha: 0.85),
                    shadows: [
                      Shadow(
                        color: AppPalette.videoScrim.withValues(alpha: 0.50),
                        offset: Offset(0, 1),
                        blurRadius: 3.0,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
