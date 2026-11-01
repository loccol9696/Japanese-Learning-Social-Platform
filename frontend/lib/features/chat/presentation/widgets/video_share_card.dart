import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../data/models/chat_models.dart';
import '../chat_format.dart';

/// Thẻ video trong tin nhắn chia sẻ: ảnh bìa, tiêu đề, người đăng, cấp JLPT và
/// mốc thời gian (nếu người gửi chọn một câu phụ đề cụ thể).
class VideoShareCard extends StatelessWidget {
  final SharedVideo video;
  final int? startMs;
  final VoidCallback? onTap;

  const VideoShareCard({
    super.key,
    required this.video,
    this.startMs,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (!video.available) return _buildUnavailable();

    final hasStart = (startMs ?? 0) >= 1000;
    return Material(
      color: AppPalette.background.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 220,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 10,
                    child: video.thumbnailUrl.isEmpty
                        ? ColoredBox(color: AppPalette.surfaceHigh)
                        : Image.network(
                            video.thumbnailUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (_, _, _) =>
                                ColoredBox(color: AppPalette.surfaceHigh),
                          ),
                  ),
                  Positioned.fill(
                    child: Center(
                      child: Icon(
                        Icons.play_circle_fill_rounded,
                        size: 44,
                        color: AppPalette.onVideoMuted,
                      ),
                    ),
                  ),
                  if (video.duration > 0)
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: _Pill(label: formatSeconds(video.duration)),
                    ),
                  if (video.jlptLevel != null)
                    Positioned(
                      left: 6,
                      top: 6,
                      child: _Pill(label: video.jlptLevel!),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppPalette.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    if (video.creatorName.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          video.creatorName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppPalette.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    if (hasStart)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          children: [
                            Icon(
                              Icons.schedule_rounded,
                              size: 14,
                              color: AppPalette.accent,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Xem từ ${formatMillis(startMs!)}',
                              style: TextStyle(
                                color: AppPalette.accent,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUnavailable() {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppPalette.background.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.videocam_off_outlined, color: AppPalette.textSecondary),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Video không còn khả dụng',
              style: TextStyle(color: AppPalette.textSecondary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;

  const _Pill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppPalette.videoScrim.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: AppPalette.onVideo,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
