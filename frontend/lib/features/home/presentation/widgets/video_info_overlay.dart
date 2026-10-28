import 'package:flutter/material.dart';

import '../../../../core/theme/adaptive_video_theme.dart';
import '../../domain/models/video_post.dart';
import '../../../../core/theme/app_palette.dart';

/// Thông tin video ở góc dưới: @username ở dòng trên; dòng dưới là tên video kèm huy hiệu JLPT viền xanh.
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
    final hasCreator = post.creatorTag.isNotEmpty;
    final hasJlpt = post.jlptLevel.isNotEmpty;
    final hasTitle = post.topicTag.isNotEmpty;

    if (!hasCreator && !hasJlpt && !hasTitle) {
      return const SizedBox.shrink();
    }

    final shadow = [
      Shadow(
        color: AppPalette.videoScrim.withValues(alpha: 0.60),
        offset: const Offset(0, 1),
        blurRadius: 4.0,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Dòng 1: @username
        if (hasCreator)
          GestureDetector(
            onTap: onCreatorTap,
            behavior: HitTestBehavior.opaque,
            child: Text(
              post.creatorTag,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.w800,
                color: AppPalette.onVideo,
                shadows: shadow,
              ),
            ),
          ),

        // Dòng 2: tên video kèm huy hiệu JLPT viền xanh
        if (hasTitle || hasJlpt) ...[
          if (hasCreator) const SizedBox(height: 6.0),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (hasTitle) ...[
                Flexible(
                  child: Text(
                    post.topicTag,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                      color: AppPalette.onVideo.withValues(alpha: 0.9),
                      shadows: shadow,
                    ),
                  ),
                ),
              ],
              if (hasTitle && hasJlpt) const SizedBox(width: 10.0),
              if (hasJlpt)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12.0,
                    vertical: 3.0,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16.0),
                    border: Border.all(color: AppPalette.info, width: 1.2),
                  ),
                  child: Text(
                    post.jlptLevel,
                    style: TextStyle(
                      fontSize: 13.0,
                      fontWeight: FontWeight.w800,
                      color: AppPalette.info,
                      letterSpacing: 0.2,
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
