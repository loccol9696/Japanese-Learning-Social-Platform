import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/auth/auth_guard.dart';
import '../../../../core/theme/adaptive_video_theme.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/data/auth_session.dart';
import '../../domain/models/video_post.dart';
import 'subtitle_mode.dart';
import '../../../../core/theme/app_palette.dart';

class InteractionSidebar extends StatefulWidget {
  final VideoPost post;
  final AdaptiveVideoTheme? theme;
  final SubtitleMode subtitleMode;
  final bool? isLikedOverride;
  final int? likeCountOverride;
  final VoidCallback? onToggleSubtitles;
  final VoidCallback? onLikeToggle;
  final VoidCallback? onSaveToggle;
  final VoidCallback? onFollowToggle;
  final VoidCallback? onCommentTap;
  final VoidCallback? onShareTap;
  final VoidCallback? onScriptTap;
  final bool allowAccountActions;

  const InteractionSidebar({
    super.key,
    required this.post,
    this.theme,
    this.subtitleMode = SubtitleMode.bilingual,
    this.isLikedOverride,
    this.likeCountOverride,
    this.onToggleSubtitles,
    this.onLikeToggle,
    this.onSaveToggle,
    this.onFollowToggle,
    this.onCommentTap,
    this.onShareTap,
    this.onScriptTap,
    this.allowAccountActions = true,
  });

  @override
  State<InteractionSidebar> createState() => _InteractionSidebarState();
}

class _InteractionSidebarState extends State<InteractionSidebar>
    with TickerProviderStateMixin {
  static Color get _accentBlue => AppPalette.info;

  late final AnimationController _likeScaleController;

  late bool _isLiked;
  late bool _isSaved;
  late bool _isFollowing;
  late int _likeCount;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.post.isLiked;
    _isSaved = widget.post.isSaved;
    _isFollowing = widget.post.isFollowing;
    _likeCount = widget.post.likeCount;

    _likeScaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      lowerBound: 1.0,
      upperBound: 1.3,
    );
  }

  @override
  void didUpdateWidget(covariant InteractionSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id ||
        oldWidget.post.isLiked != widget.post.isLiked ||
        oldWidget.post.isSaved != widget.post.isSaved ||
        oldWidget.post.isFollowing != widget.post.isFollowing ||
        oldWidget.post.likeCount != widget.post.likeCount) {
      _isLiked = widget.post.isLiked;
      _isSaved = widget.post.isSaved;
      _isFollowing = widget.post.isFollowing;
      _likeCount = widget.post.likeCount;
    }
  }

  @override
  void dispose() {
    _likeScaleController.dispose();
    super.dispose();
  }

  Future<void> _handleLike() async {
    if (!AuthSession.instance.isAuthenticated) {
      await requireAuthentication(
        context,
        message: 'Vui lòng đăng nhập để thả tim video này.',
      );
      return;
    }

    setState(() {
      _isLiked = !_isLiked;
      if (_isLiked) {
        _likeCount += 1;
      } else {
        _likeCount = math.max(0, _likeCount - 1);
      }
    });

    _likeScaleController.forward().then((_) {
      _likeScaleController.reverse();
    });

    widget.onLikeToggle?.call();
  }

  void _handleFollow() {
    if (!widget.allowAccountActions) {
      widget.onFollowToggle?.call();
      return;
    }
    setState(() {
      _isFollowing = !_isFollowing;
    });
    widget.onFollowToggle?.call();
  }

  void _handleSave() {
    if (!widget.allowAccountActions) {
      widget.onSaveToggle?.call();
      return;
    }
    setState(() => _isSaved = !_isSaved);
    widget.onSaveToggle?.call();
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    final activeTheme =
        widget.theme ?? const AdaptiveVideoTheme(isLight: false);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 1. Creator Avatar & Follow Button
        _buildCreatorAvatar(activeTheme),
        const SizedBox(height: 8.0),

        // 2. Like / Heart Button
        _buildLikeButton(activeTheme),
        const SizedBox(height: 6.0),

        // 3. Comments Button
        _buildActionButton(
          theme: activeTheme,
          countText: _formatCount(widget.post.commentCount),
          onTap: widget.onCommentTap,
          icon: Icons.chat_bubble_outline_rounded,
          countFontSize: 10.0,
          countColor: AppPalette.onVideo,
        ),
        const SizedBox(height: 8.0),
        _buildActionButton(
          theme: activeTheme,
          icon: _isSaved
              ? Icons.bookmark_rounded
              : Icons.bookmark_border_rounded,
          countText: 'Lưu',
          onTap: _handleSave,
          iconColor: _isSaved ? _accentBlue : AppPalette.onVideo,
          countColor: _isSaved ? _accentBlue : AppPalette.onVideo,
        ),
        const SizedBox(height: 8.0),

        // 4. Share Button
        _buildActionButton(
          theme: activeTheme,
          icon: Icons.reply_outlined,
          flipIcon: true,
          countText: _formatCount(widget.post.shareCount),
          onTap: widget.onShareTap,
        ),
        const SizedBox(height: 6.0),

        // 5. Kịch bản (mở danh sách toàn bộ câu thoại)
        _buildActionButton(
          theme: activeTheme,
          icon: Icons.article_outlined,
          countText: 'Kịch bản',
          onTap: widget.onScriptTap,
        ),
        const SizedBox(height: 6.0),

        // 6. Subtitle Toggle Button (below script)
        _buildSubtitleToggleButton(activeTheme),
      ],
    );
  }

  Widget _buildSubtitleToggleButton(AdaptiveVideoTheme theme) {
    final isVisible = widget.subtitleMode != SubtitleMode.off;
    final label = switch (widget.subtitleMode) {
      SubtitleMode.bilingual => 'Song ngữ',
      SubtitleMode.japaneseOnly => 'Tiếng Nhật',
      SubtitleMode.off => 'Tắt',
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: widget.onToggleSubtitles,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: 36.0,
            height: 36.0,
            child: Center(
              child: Icon(
                isVisible
                    ? Icons.subtitles_outlined
                    : Icons.subtitles_off_outlined,
                size: 26.0,
                color: isVisible
                    ? (theme.isLight ? theme.primaryAdaptive : AppPalette.onVideo)
                    : (theme.isLight
                          ? theme.textSecondary.withValues(alpha: 0.5)
                          : AppPalette.onVideoMuted),
                shadows: theme.textShadows,
              ),
            ),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.0,
            fontWeight: isVisible ? FontWeight.bold : FontWeight.w500,
            color: isVisible
                ? (theme.isLight ? theme.primaryAdaptive : AppPalette.onVideo)
                : (theme.isLight
                      ? theme.textSecondary.withValues(alpha: 0.6)
                      : AppPalette.onVideoMuted),
            shadows: theme.textShadows,
          ),
        ),
      ],
    );
  }

  Widget _buildCreatorAvatar(AdaptiveVideoTheme theme) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 48.0,
          height: 48.0,
          padding: const EdgeInsets.all(2.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                AppColors.periwinkle,
                AppColors.lavender,
                AppColors.sakuraPink,
              ],
              begin: Alignment.bottomLeft,
              end: Alignment.topRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.lavender.withValues(alpha: 0.5),
                blurRadius: 15.0,
              ),
            ],
          ),
          child: ClipOval(
            child: Image.network(
              widget.post.creatorAvatarUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                color: AppColors.surfaceContainerHigh,
                child: Icon(Icons.person, color: AppColors.periwinkle),
              ),
            ),
          ),
        ),
        // Follow / Unfollow Badge Button
        Positioned(
          bottom: -8.0,
          child: GestureDetector(
            onTap: _handleFollow,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 20.0,
              height: 20.0,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isFollowing
                    ? AppColors.sakuraPink
                    : (theme.isLight
                          ? theme.primaryAdaptive
                          : AppColors.periwinkle),
                boxShadow: [
                  BoxShadow(
                    color: _isFollowing
                        ? AppColors.sakuraPink.withValues(alpha: 0.6)
                        : AppPalette.shadow,
                    blurRadius: 8.0,
                  ),
                ],
              ),
              child: Icon(
                _isFollowing ? Icons.check_rounded : Icons.add_rounded,
                size: 14.0,
                color: AppPalette.onVideo,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLikeButton(AdaptiveVideoTheme theme) {
    final isLiked = widget.isLikedOverride ?? _isLiked;
    final likeCount = widget.likeCountOverride ?? _likeCount;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _handleLike,
          behavior: HitTestBehavior.opaque,
          child: ScaleTransition(
            scale: _likeScaleController,
            child: SizedBox(
              width: 36.0,
              height: 36.0,
              child: Center(
                child: Icon(
                  isLiked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  size: 26.0,
                  color: isLiked
                      ? AppColors.likeRed
                      : (theme.isLight ? theme.primaryAdaptive : AppPalette.onVideo),
                  shadows: _isLiked
                      ? [
                          const Shadow(
                            color: AppColors.likeRed,
                            blurRadius: 10.0,
                          ),
                        ]
                      : theme.textShadows,
                ),
              ),
            ),
          ),
        ),
        Text(
          _formatCount(likeCount),
          style: TextStyle(
            fontSize: 10.0,
            fontWeight: FontWeight.w600,
            color: theme.isLight ? theme.primaryAdaptive : AppPalette.onVideo,
            shadows: theme.textShadows,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required AdaptiveVideoTheme theme,
    IconData? icon,
    String? countText,
    VoidCallback? onTap,
    Widget? customIcon,
    double iconSize = 26.0,
    bool flipIcon = false,
    Color? iconColor,
    double countFontSize = 10.0,
    Color? countColor,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: 36.0,
            height: 36.0,
            child:
                customIcon ??
                Center(
                  child: Transform.flip(
                    flipX: flipIcon,
                    child: Icon(
                      icon,
                      size: iconSize,
                      color:
                          iconColor ??
                          (theme.isLight
                              ? theme.primaryAdaptive
                              : AppPalette.onVideo),
                      shadows: theme.textShadows,
                    ),
                  ),
                ),
          ),
        ),
        const SizedBox(height: 2.0),
        if (countText != null)
          Text(
            countText,
            style: TextStyle(
              fontSize: countFontSize,
              fontWeight: FontWeight.w600,
              color:
                  countColor ??
                  (theme.isLight ? theme.primaryAdaptive : AppPalette.onVideo),
              shadows: theme.textShadows,
            ),
          ),
      ],
    );
  }
}
