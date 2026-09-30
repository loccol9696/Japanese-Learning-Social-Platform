import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/localization/locale_manager.dart';
import '../../../../core/theme/adaptive_video_theme.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/models/video_post.dart';

class InteractionSidebar extends StatefulWidget {
  final VideoPost post;
  final AdaptiveVideoTheme? theme;
  final bool isSubtitlesVisible;
  final VoidCallback? onToggleSubtitles;
  final VoidCallback? onLikeToggle;
  final VoidCallback? onFollowToggle;
  final VoidCallback? onCommentTap;
  final VoidCallback? onShareTap;

  const InteractionSidebar({
    super.key,
    required this.post,
    this.theme,
    this.isSubtitlesVisible = true,
    this.onToggleSubtitles,
    this.onLikeToggle,
    this.onFollowToggle,
    this.onCommentTap,
    this.onShareTap,
  });

  @override
  State<InteractionSidebar> createState() => _InteractionSidebarState();
}

class _InteractionSidebarState extends State<InteractionSidebar>
    with TickerProviderStateMixin {
  late final AnimationController _discController;
  late final AnimationController _likeScaleController;
  late final AnimationController _noteBounceController;

  late bool _isLiked;
  late bool _isFollowing;
  late int _likeCount;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.post.isLiked;
    _isFollowing = widget.post.isFollowing;
    _likeCount = widget.post.likeCount;

    _discController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    _likeScaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      lowerBound: 1.0,
      upperBound: 1.3,
    );

    _noteBounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant InteractionSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id) {
      _isLiked = widget.post.isLiked;
      _isFollowing = widget.post.isFollowing;
      _likeCount = widget.post.likeCount;
    }
  }

  @override
  void dispose() {
    _discController.dispose();
    _likeScaleController.dispose();
    _noteBounceController.dispose();
    super.dispose();
  }

  void _handleLike() {
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
    setState(() {
      _isFollowing = !_isFollowing;
    });
    widget.onFollowToggle?.call();
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
        // 0. Subtitle Toggle Button (placed directly above user avatar)
        _buildSubtitleToggleButton(activeTheme),
        const SizedBox(height: 14.0),

        // 1. Creator Avatar & Follow Button
        _buildCreatorAvatar(activeTheme),
        const SizedBox(height: 16.0),

        // 2. Like / Heart Button
        _buildLikeButton(activeTheme),
        const SizedBox(height: 14.0),

        // 3. Comments Button
        _buildActionButton(
          theme: activeTheme,
          icon: Icons.chat_bubble_rounded,
          countText: _formatCount(widget.post.commentCount),
          onTap: widget.onCommentTap,
        ),
        const SizedBox(height: 14.0),

        // 4. Share Button
        _buildActionButton(
          theme: activeTheme,
          icon: Icons.reply_rounded,
          countText: _formatCount(widget.post.shareCount),
          onTap: widget.onShareTap,
        ),
        const SizedBox(height: 16.0),

        // 5. Rotating Vinyl Disc
        _buildRotatingDisc(activeTheme),
      ],
    );
  }

  Widget _buildSubtitleToggleButton(AdaptiveVideoTheme theme) {
    final isVisible = widget.isSubtitlesVisible;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: widget.onToggleSubtitles,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: 44.0,
            height: 44.0,
            child: Center(
              child: Icon(
                isVisible
                    ? Icons.subtitles_rounded
                    : Icons.subtitles_off_rounded,
                size: 28.0,
                color: isVisible
                    ? (theme.isLight ? theme.primaryAdaptive : Colors.white)
                    : (theme.isLight
                          ? theme.textSecondary.withValues(alpha: 0.5)
                          : Colors.white54),
                shadows: theme.textShadows,
              ),
            ),
          ),
        ),
        const SizedBox(height: 2.0),
        Text(
          appStrings.subtitle,
          style: TextStyle(
            fontSize: 11.0,
            fontWeight: isVisible ? FontWeight.bold : FontWeight.w500,
            color: isVisible
                ? (theme.isLight ? theme.primaryAdaptive : Colors.white)
                : (theme.isLight
                      ? theme.textSecondary.withValues(alpha: 0.6)
                      : Colors.white60),
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
            gradient: const LinearGradient(
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
                child: const Icon(Icons.person, color: AppColors.periwinkle),
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
              width: 22.0,
              height: 22.0,
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
                        : Colors.black.withValues(alpha: 0.25),
                    blurRadius: 8.0,
                  ),
                ],
              ),
              child: Icon(
                _isFollowing ? Icons.check_rounded : Icons.add_rounded,
                size: 16.0,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLikeButton(AdaptiveVideoTheme theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _handleLike,
          behavior: HitTestBehavior.opaque,
          child: ScaleTransition(
            scale: _likeScaleController,
            child: SizedBox(
              width: 44.0,
              height: 44.0,
              child: Center(
                child: Icon(
                  _isLiked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  size: 30.0,
                  color: _isLiked
                      ? AppColors.sakuraPink
                      : (theme.isLight ? theme.primaryAdaptive : Colors.white),
                  shadows: _isLiked
                      ? [
                          const Shadow(
                            color: AppColors.sakuraPink,
                            blurRadius: 10.0,
                          ),
                        ]
                      : theme.textShadows,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 2.0),
        Text(
          _formatCount(_likeCount),
          style: TextStyle(
            fontSize: 12.0,
            fontWeight: FontWeight.w600,
            color: theme.isLight ? theme.primaryAdaptive : Colors.white,
            shadows: theme.textShadows,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required AdaptiveVideoTheme theme,
    required IconData icon,
    required String countText,
    VoidCallback? onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: 44.0,
            height: 44.0,
            child: Center(
              child: Icon(
                icon,
                size: 28.0,
                color: theme.isLight ? theme.primaryAdaptive : Colors.white,
                shadows: theme.textShadows,
              ),
            ),
          ),
        ),
        const SizedBox(height: 2.0),
        Text(
          countText,
          style: TextStyle(
            fontSize: 12.0,
            fontWeight: FontWeight.w600,
            color: theme.isLight ? theme.primaryAdaptive : Colors.white,
            shadows: theme.textShadows,
          ),
        ),
      ],
    );
  }

  Widget _buildRotatingDisc(AdaptiveVideoTheme theme) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        RotationTransition(
          turns: _discController,
          child: Container(
            width: 42.0,
            height: 42.0,
            padding: const EdgeInsets.all(4.0),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.isLight ? Colors.white : AppColors.surfaceDim,
              border: Border.all(
                color: theme.isLight
                    ? const Color(0xFF1E212D).withValues(alpha: 0.3)
                    : AppColors.lavender,
                width: 2.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: theme.isLight
                      ? Colors.black.withValues(alpha: 0.1)
                      : AppColors.lavender.withValues(alpha: 0.5),
                  blurRadius: 12.0,
                ),
              ],
            ),
            child: ClipOval(
              child: Image.network(
                widget.post.audioDiscImageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: AppColors.surfaceContainerHighest,
                  child: Icon(
                    Icons.album_rounded,
                    size: 16.0,
                    color: theme.isLight
                        ? const Color(0xFF1E212D)
                        : AppColors.lavender,
                  ),
                ),
              ),
            ),
          ),
        ),
        // Animated bouncing music note
        Positioned(
          top: -6.0,
          right: -4.0,
          child: AnimatedBuilder(
            animation: _noteBounceController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, -4.0 * _noteBounceController.value),
                child: child,
              );
            },
            child: const Icon(
              Icons.music_note_rounded,
              size: 16.0,
              color: AppColors.sakuraPink,
              shadows: [Shadow(color: AppColors.sakuraPink, blurRadius: 8.0)],
            ),
          ),
        ),
      ],
    );
  }
}
