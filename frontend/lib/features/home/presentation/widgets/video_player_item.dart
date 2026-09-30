import 'package:flutter/material.dart';
import '../../../../core/theme/adaptive_video_theme.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/models/video_post.dart';
import 'interaction_sidebar.dart';
import 'ruby_subtitle_widget.dart';
import 'streak_xp_badge.dart';
import 'video_info_overlay.dart';

class VideoPlayerItem extends StatefulWidget {
  final VideoPost post;
  final VoidCallback? onLikeToggle;
  final VoidCallback? onFollowToggle;

  const VideoPlayerItem({
    super.key,
    required this.post,
    this.onLikeToggle,
    this.onFollowToggle,
  });

  @override
  State<VideoPlayerItem> createState() => _VideoPlayerItemState();
}

class _VideoPlayerItemState extends State<VideoPlayerItem>
    with SingleTickerProviderStateMixin {
  bool _isPlaying = true;
  bool _showRipple = false;
  bool _showSubtitles = true;

  late final AnimationController _rippleController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _scaleAnimation = Tween<double>(begin: 0.75, end: 1.1).animate(
      CurvedAnimation(parent: _rippleController, curve: Curves.easeOutCubic),
    );

    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 70),
    ]).animate(_rippleController);
  }

  @override
  void dispose() {
    _rippleController.dispose();
    super.dispose();
  }

  void _handleTapToPlayPause() {
    setState(() {
      _isPlaying = !_isPlaying;
      _showRipple = true;
    });

    _rippleController.forward(from: 0.0).then((_) {
      if (mounted) {
        setState(() {
          _showRipple = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Dynamic contrast theme based on background brightness
    final theme = AdaptiveVideoTheme(isLight: widget.post.isLightBackground);

    return GestureDetector(
      onTap: _handleTapToPlayPause,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Background Video / Simulation Image
          Image.network(
            widget.post.backgroundImageUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              color: AppColors.surfaceContainerHighest,
              child: Center(
                child: Icon(
                  Icons.image_not_supported_rounded,
                  color: theme.primaryAdaptive,
                  size: 48.0,
                ),
              ),
            ),
          ),

          // 2. Subtle Dark Tint Overlay (only for dark background)
          if (!widget.post.isLightBackground)
            Container(
              color: AppColors.surfaceContainerHighest.withValues(alpha: 0.2),
            ),

          // 3. Multi-tier Gradient Scrims
          // Top Scrim
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 180.0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: theme.topScrimColors,
                ),
              ),
            ),
          ),
          // Bottom Scrim
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 380.0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: theme.bottomScrimColors,
                ),
              ),
            ),
          ),

          // 4. Streak & XP Badge Pill (Top-left)
          Positioned(
            top: 60.0,
            left: 16.0,
            child: SafeArea(
              bottom: false,
              child: StreakXpBadge(
                streakDays: widget.post.streakDays,
                xp: widget.post.xp,
                theme: theme,
              ),
            ),
          ),

          // 5. Center Play / Pause Animated Ripple Icon
          if (_showRipple)
            Center(
              child: FadeTransition(
                opacity: _opacityAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    width: 68.0,
                    height: 68.0,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.playRippleBackground,
                      border: Border.all(
                        color: theme.playRippleBorder,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: theme.playRippleBorder.withValues(alpha: 0.35),
                          blurRadius: 20.0,
                        ),
                      ],
                    ),
                    child: Icon(
                      _isPlaying ? Icons.play_arrow_rounded : Icons.pause_rounded,
                      size: 38.0,
                      color: theme.playRippleIcon,
                    ),
                  ),
                ),
              ),
            ),

          // 6. Right Side Interaction Sidebar
          Positioned(
            right: 12.0,
            bottom: 100.0,
            child: InteractionSidebar(
              post: widget.post,
              theme: theme,
              isSubtitlesVisible: _showSubtitles,
              onToggleSubtitles: () {
                setState(() {
                  _showSubtitles = !_showSubtitles;
                });
              },
              onLikeToggle: widget.onLikeToggle,
              onFollowToggle: widget.onFollowToggle,
            ),
          ),

          // 7. Bottom Subtitle & Video Metadata Overlay
          Positioned(
            left: 16.0,
            right: 76.0,
            bottom: 95.0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedCrossFade(
                  firstChild: Padding(
                    padding: const EdgeInsets.only(bottom: 10.0),
                    child: RubySubtitleWidget(
                      rubySegments: widget.post.rubySegments,
                      translation: widget.post.translation,
                      theme: theme,
                    ),
                  ),
                  secondChild: const SizedBox.shrink(),
                  crossFadeState: _showSubtitles
                      ? CrossFadeState.showFirst
                      : CrossFadeState.showSecond,
                  duration: const Duration(milliseconds: 250),
                ),
                VideoInfoOverlay(
                  post: widget.post,
                  theme: theme,
                ),
              ],
            ),
          ),

          // 8. Video Progress Scrubber Bar
          Positioned(
            bottom: 84.0,
            left: 0,
            right: 0,
            child: Container(
              height: 3.0,
              color: theme.progressTrack,
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: widget.post.progress,
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.progressActive,
                    borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(2.0),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.progressGlow,
                        blurRadius: 8.0,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
