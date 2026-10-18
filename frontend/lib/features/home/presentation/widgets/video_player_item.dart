import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/localization/locale_manager.dart';
import '../../../../core/theme/adaptive_video_theme.dart';
import '../../../../core/video/autoplay_policy.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/models/video_post.dart';
import '../../domain/models/ruby_segment.dart';
import 'interaction_sidebar.dart';
import 'ruby_subtitle_widget.dart';
import 'streak_xp_badge.dart';
import 'video_info_overlay.dart';

class VideoPlayerItem extends StatefulWidget {
  final VideoPost post;
  final ValueChanged<bool>? onLikeChanged;
  final VoidCallback? onFollowToggle;

  const VideoPlayerItem({
    super.key,
    required this.post,
    this.onLikeChanged,
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
  // Đang phát không tiếng vì trình duyệt chưa cho tự phát có tiếng -> hiện nút bật tiếng.
  bool _isMuted = false;
  double _videoProgress = 0.0;

  late final AnimationController _rippleController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;
  VideoPlayerController? _videoController;
  SubtitleCue? _activeSubtitle;

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
    _initializeVideo();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _rippleController.dispose();
    super.dispose();
  }

  Future<void> _initializeVideo() async {
    final videoUrl = widget.post.videoUrl;
    if (videoUrl.isEmpty) return;

    final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
    _videoController = controller;
    try {
      await controller.initialize();
      await controller.setLooping(true);
      // Phát có tiếng nếu được phép; web chưa có tương tác (vd. tải lại trang) thì
      // trình duyệt chặn tiếng -> phát không tiếng và chờ người dùng chạm để bật.
      final muted = !canAutoplayWithSound();
      await controller.setVolume(muted ? 0 : 1);
      _isMuted = muted;
      controller.addListener(_updateActiveSubtitle);
      if (!mounted || _videoController != controller) return;
      setState(() {});
      _updateActiveSubtitle();

      try {
        await controller.play();
      } catch (error) {
        // Browsers may block autoplay even when the video is muted.
        debugPrint('Video autoplay was blocked: $error');
        if (mounted) {
          setState(() => _isPlaying = false);
        }
      }
    } catch (error) {
      debugPrint('Video initialization failed: $error');
      await controller.dispose();
      if (_videoController == controller) {
        _videoController = null;
      }
    }
  }

  void _updateActiveSubtitle() {
    final controller = _videoController;
    if (!mounted || controller == null || !controller.value.isInitialized) {
      return;
    }

    final position = controller.value.position;
    final duration = controller.value.duration;
    SubtitleCue? active;
    for (final cue in widget.post.subtitleCues) {
      if (cue.contains(position)) {
        active = cue;
        break;
      }
    }

    final progress = duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;
    if (active?.start != _activeSubtitle?.start ||
        active?.end != _activeSubtitle?.end ||
        progress != _videoProgress) {
      setState(() {
        _activeSubtitle = active;
        _videoProgress = progress;
      });
    }
  }

  Future<void> _seekToFraction(double fraction) async {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;
    final duration = controller.value.duration;
    if (duration.inMilliseconds <= 0) return;
    await controller.seekTo(
      Duration(milliseconds: (duration.inMilliseconds * fraction).round()),
    );
  }

  void _handleTapToPlayPause() {
    final controller = _videoController;
    // Chạm lần đầu khi đang tắt tiếng: bật tiếng (và tiếp tục phát) thay vì tạm dừng.
    if (controller != null && controller.value.isInitialized && _isMuted) {
      setState(() {
        _isMuted = false;
        _isPlaying = true;
        _showRipple = true;
      });
      controller.setVolume(1);
      controller.play().catchError((error) {
        debugPrint('Video playback with audio failed: $error');
      });
      _rippleController.forward(from: 0.0).then((_) {
        if (mounted) {
          setState(() => _showRipple = false);
        }
      });
      return;
    }

    setState(() {
      _isPlaying = !_isPlaying;
      _showRipple = true;
    });
    if (controller != null && controller.value.isInitialized) {
      if (_isPlaying) {
        controller.play().catchError((error) {
          debugPrint('Video playback failed: $error');
          if (mounted) {
            setState(() => _isPlaying = false);
          }
        });
      } else {
        controller.pause();
      }
    }

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
    final activeCue = _activeSubtitle;
    final displayedSegments = widget.post.subtitleCues.isEmpty
        ? widget.post.rubySegments
        : activeCue == null
        ? const <RubySegment>[]
        : [RubySegment(kanji: activeCue.text, furigana: '')];
    final displayedTranslation = widget.post.subtitleCues.isEmpty
        ? widget.post.translation
        : activeCue?.translation ?? '';

    return GestureDetector(
      onTap: _handleTapToPlayPause,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Background Video / Simulation Image
          _buildVideoBackground(theme),

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

          // 4. Streak & XP Badge Pill (Top-left) — chỉ khi có dữ liệu thật
          if (widget.post.streakDays != null && widget.post.xp != null)
            Positioned(
              top: 60.0,
              left: 16.0,
              child: SafeArea(
                bottom: false,
                child: StreakXpBadge(
                  streakDays: widget.post.streakDays!,
                  xp: widget.post.xp!,
                  theme: theme,
                ),
              ),
            ),

          // 4b. Gợi ý bật tiếng khi trình duyệt buộc phát không tiếng
          if (_isMuted && _videoController?.value.isInitialized == true)
            Positioned(
              top: 72.0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14.0,
                      vertical: 8.0,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(20.0),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.volume_off_rounded,
                          color: Colors.white,
                          size: 18.0,
                        ),
                        const SizedBox(width: 6.0),
                        Text(
                          appStrings.homeTapToUnmute,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.0,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
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
                      _isPlaying
                          ? Icons.play_arrow_rounded
                          : Icons.pause_rounded,
                      size: 38.0,
                      color: theme.playRippleIcon,
                    ),
                  ),
                ),
              ),
            ),

          // 6 + 7. Bố cục dưới: khối thông tin (cao cố định trong suốt video) ở đáy;
          // cột tương tác căn giữa theo chiều dọc trong phần phía trên khối thông tin.
          // Phụ đề (số dòng đổi liên tục) nằm chồng ở đáy phần đó nên KHÔNG làm cột nút
          // nhảy lên xuống; cả phụ đề và thông tin đều rộng hết màn hình.
          Positioned.fill(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Positioned(
                        left: 16.0,
                        right: 16.0,
                        bottom: 0,
                        child: AnimatedCrossFade(
                          firstChild: RubySubtitleWidget(
                            rubySegments: displayedSegments,
                            translation: displayedTranslation,
                            theme: theme,
                          ),
                          secondChild: const SizedBox.shrink(),
                          crossFadeState: _showSubtitles
                              ? CrossFadeState.showFirst
                              : CrossFadeState.showSecond,
                          duration: const Duration(milliseconds: 250),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 12.0),
                          child: InteractionSidebar(
                            post: widget.post,
                            theme: theme,
                            isSubtitlesVisible: _showSubtitles,
                            onToggleSubtitles: () {
                              setState(() {
                                _showSubtitles = !_showSubtitles;
                              });
                            },
                            onLikeChanged: widget.onLikeChanged,
                            onFollowToggle: widget.onFollowToggle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 10.0, 16.0, 16.0),
                  child: VideoInfoOverlay(post: widget.post, theme: theme),
                ),
              ],
            ),
          ),

          // 8. Video Progress Scrubber Bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SizedBox(
              height: 22.0,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) => _seekToFraction(
                      (details.localPosition.dx / constraints.maxWidth).clamp(
                        0.0,
                        1.0,
                      ),
                    ),
                    onHorizontalDragUpdate: (details) => _seekToFraction(
                      (details.localPosition.dx / constraints.maxWidth).clamp(
                        0.0,
                        1.0,
                      ),
                    ),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: SizedBox(
                        height: 3.0,
                        child: Stack(
                          children: [
                            Container(color: theme.progressTrack),
                            FractionallySizedBox(
                              widthFactor: _videoProgress,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: theme.progressActive,
                                  boxShadow: [
                                    BoxShadow(
                                      color: theme.progressGlow,
                                      blurRadius: 8.0,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoBackground(AdaptiveVideoTheme theme) {
    final controller = _videoController;
    if (controller != null && controller.value.isInitialized) {
      final aspectRatio = controller.value.aspectRatio;
      final isLandscape = aspectRatio > 1.15;

      if (!isLandscape) {
        return FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: controller.value.size.width,
            height: controller.value.size.height,
            child: VideoPlayer(controller),
          ),
        );
      }

      return Stack(
        fit: StackFit.expand,
        children: [
          _buildLandscapeBackdrop(theme),
          // Hơi lệch lên trên để cân với khối phụ đề/thông tin phía dưới.
          Align(
            alignment: const Alignment(0, -0.15),
            child: AspectRatio(
              aspectRatio: aspectRatio,
              child: VideoPlayer(controller),
            ),
          ),
        ],
      );
    }

    if (widget.post.backgroundImageUrl.isNotEmpty) {
      return Image.network(
        widget.post.backgroundImageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _videoPlaceholder(theme),
      );
    }
    return _videoPlaceholder(theme);
  }

  Widget _buildLandscapeBackdrop(AdaptiveVideoTheme theme) {
    final thumbnailUrl = widget.post.backgroundImageUrl;
    if (thumbnailUrl.isEmpty) {
      return Container(color: AppColors.surfaceContainerHighest);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Nền mờ từ khung hình video (kiểu TikTok/Reels) thay cho ảnh phóng to sắc nét.
        ImageFiltered(
          imageFilter: ImageFilter.blur(
            sigmaX: 28,
            sigmaY: 28,
            tileMode: TileMode.decal,
          ),
          child: Image.network(
            thumbnailUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                Container(color: AppColors.surfaceContainerHighest),
          ),
        ),
        Container(color: Colors.black.withValues(alpha: 0.45)),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.18),
                theme.bottomScrimColors.last.withValues(alpha: 0.55),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _videoPlaceholder(AdaptiveVideoTheme theme) {
    return Container(
      color: AppColors.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.video_library_outlined,
          color: theme.primaryAdaptive,
          size: 48.0,
        ),
      ),
    );
  }
}
