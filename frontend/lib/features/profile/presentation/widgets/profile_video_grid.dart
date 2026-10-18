import 'package:flutter/material.dart';

import '../../../../core/localization/locale_manager.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/profile_video.dart';

/// Lưới video 3 cột kiểu TikTok dùng cho các tab của màn Profile.
class ProfileVideoGrid extends StatelessWidget {
  const ProfileVideoGrid({
    super.key,
    required this.videos,
    required this.tileBuilder,
  });

  final List<ProfileVideo> videos;
  final Widget Function(ProfileVideo video) tileBuilder;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      // Luôn cuộn được để kéo xuống làm mới kể cả khi ít video.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(0, 1.5, 0, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.74,
        crossAxisSpacing: 1.5,
        mainAxisSpacing: 1.5,
      ),
      itemCount: videos.length,
      itemBuilder: (context, index) => tileBuilder(videos[index]),
    );
  }
}

/// Một ô video: thumbnail, gradient tối phía dưới, badge góc trên và
/// chỉ số (lượt xem/thích) góc dưới.
class ProfileVideoTile extends StatelessWidget {
  const ProfileVideoTile({
    super.key,
    required this.video,
    required this.snackPrefix,
    required this.bottomIcon,
    required this.bottomIconColor,
    required this.bottomText,
    this.topLeftBadge,
    this.topRightBadge,
  });

  final ProfileVideo video;
  final String snackPrefix;
  final IconData bottomIcon;
  final Color bottomIconColor;
  final String bottomText;
  final Widget? topLeftBadge;
  final Widget? topRightBadge;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$snackPrefix: ${video.title}'),
            backgroundColor: AppColors.socialSurface,
          ),
        );
      },
      child: Container(
        color: AppColors.socialSurface,
        child: Stack(
          fit: StackFit.expand,
          children: [
            VideoThumbnail(url: video.thumbnailUrl),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
            if (topLeftBadge != null)
              Positioned(top: 6, left: 6, child: topLeftBadge!),
            if (topRightBadge != null)
              Positioned(top: 6, right: 6, child: topRightBadge!),
            Positioned(
              left: 6,
              bottom: 6,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(bottomIcon, color: bottomIconColor, size: 14),
                  const SizedBox(width: 2),
                  Text(
                    bottomText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      shadows: [Shadow(color: Colors.black, blurRadius: 3)],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Thumbnail có placeholder khi đang tải và fallback khi URL lỗi/rỗng,
/// tránh ô video bị trống hoặc vỡ ảnh.
class VideoThumbnail extends StatelessWidget {
  const VideoThumbnail({super.key, required this.url});

  final String url;

  Widget _placeholder({bool loading = false}) => Container(
    color: AppColors.socialSurface,
    child: Center(
      child: loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.socialTextMuted,
              ),
            )
          : const Icon(
              Icons.play_circle_outline,
              color: AppColors.socialTextMuted,
              size: 28,
            ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return _placeholder();

    return Image.network(
      url,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : _placeholder(loading: true),
      errorBuilder: (context, error, stackTrace) => _placeholder(),
    );
  }
}

/// Trạng thái duyệt của video do chính mình đăng ("Chờ duyệt" / "Bị từ chối");
/// video đã duyệt không có badge.
class ModStatusBadge extends StatelessWidget {
  const ModStatusBadge({super.key, required this.video});

  final ProfileVideo video;

  /// `null` nếu video không cần badge.
  static ModStatusBadge? maybe(ProfileVideo video) =>
      video.isPending || video.isRejected ? ModStatusBadge(video: video) : null;

  @override
  Widget build(BuildContext context) {
    final rejected = video.isRejected;
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: rejected
            ? AppColors.socialRed
            : Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        rejected
            ? appStrings.profileStatusRejected
            : appStrings.profileStatusPending,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9.5,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    final reason = video.rejectionReason;
    return rejected && reason != null
        ? Tooltip(message: reason, child: badge)
        : badge;
  }
}

class JlptBadge extends StatelessWidget {
  const JlptBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Trạng thái rỗng của một tab (icon + tiêu đề + gợi ý).
class ProfileEmptyTab extends StatelessWidget {
  const ProfileEmptyTab({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    // ListView (luôn cuộn được) để kéo xuống làm mới cả khi tab trống.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 100),
      children: [
        Icon(icon, size: 44, color: Colors.white.withValues(alpha: 0.35)),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.socialTextMuted,
            fontSize: 12.5,
          ),
        ),
      ],
    );
  }
}

/// Lỗi khi tải một tab: thông báo + nút thử lại.
class ProfileTabError extends StatelessWidget {
  const ProfileTabError({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 100),
      children: [
        Icon(
          Icons.cloud_off_rounded,
          size: 44,
          color: Colors.white.withValues(alpha: 0.35),
        ),
        const SizedBox(height: 12),
        Text(
          appStrings.profileLoadFailed,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.socialTextMuted,
            fontSize: 12.5,
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: OutlinedButton(
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: AppColors.socialDivider),
            ),
            child: Text(appStrings.profileRetry),
          ),
        ),
      ],
    );
  }
}
