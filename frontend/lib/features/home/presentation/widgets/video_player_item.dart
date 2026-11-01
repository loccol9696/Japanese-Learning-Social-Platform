import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/auth/auth_guard.dart';
import '../../../../core/theme/adaptive_video_theme.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/data/auth_session.dart';
import '../../../explore/presentation/explore_screen.dart';
import '../../../chat/presentation/widgets/share_video_sheet.dart';
import '../../../follow/presentation/screens/user_profile_screen.dart';
import '../../../profile/domain/models/topic_model.dart';
import '../../domain/models/video_post.dart';
import '../../domain/models/ruby_segment.dart';
import '../screens/video_script_screen.dart';
import 'bottom_nav_dock.dart';
import 'interaction_sidebar.dart';
import 'ruby_subtitle_widget.dart';
import 'subtitle_mode.dart';
import 'video_info_overlay.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/video/app_video_playback.dart';

class VideoPlayerItem extends StatefulWidget {
  final VideoPost post;
  final VoidCallback? onLikeToggle;
  final VoidCallback? onSaveToggle;
  final VoidCallback? onFollowToggle;

  /// Báo khi người dùng theo dõi / bỏ theo dõi người đăng ngay trên trang cá nhân
  /// của họ (true = đang theo dõi), để màn chứa video cập nhật nút theo dõi.
  final ValueChanged<bool>? onCreatorFollowChanged;
  final VoidCallback? onCommentTap;
  final bool allowAccountActions;

  /// Chỉ video đang hiển thị trong PageView mới được phát và phát âm thanh.
  final bool isActive;

  /// Mở video tại mốc này (vd. khi mở video được bạn bè chia sẻ kèm câu phụ đề).
  final Duration? initialPosition;

  /// false khi video không còn hiện trên màn hình (vd. chuyển sang tab khác của Home,
  /// mở màn khác đè lên feed): video tạm dừng và phát tiếp khi true trở lại.
  /// null = luôn được phát.
  final ValueListenable<bool>? playbackAllowed;

  /// true (mặc định) khi video nằm trong Home và thanh menu dưới đè lên nội dung nên phải chừa chỗ cho nó.
  /// false ở các màn không có thanh menu (xem video từ kết quả tìm kiếm, video được chia sẻ) để video và phụ đề
  /// kéo sát đáy màn hình, không bị chừa một khoảng trống.
  final bool reserveBottomBar;

  const VideoPlayerItem({
    super.key,
    required this.post,
    this.onLikeToggle,
    this.onSaveToggle,
    this.onFollowToggle,
    this.onCreatorFollowChanged,
    this.onCommentTap,
    this.allowAccountActions = true,
    this.isActive = true,
    this.initialPosition,
    this.playbackAllowed,
    this.reserveBottomBar = true,
  });

  @override
  State<VideoPlayerItem> createState() => _VideoPlayerItemState();
}

class _FloatingHeartEffect {
  final Offset position;
  final AnimationController controller;

  const _FloatingHeartEffect({
    required this.position,
    required this.controller,
  });
}

class _VideoPlayerItemState extends State<VideoPlayerItem>
    with TickerProviderStateMixin {
  bool _isPlaying = true;
  bool _isMutedForWebAutoplay = false;
  SubtitleMode _subtitleMode = SubtitleMode.bilingual;
  bool? _doubleTapLikedOverride;
  int? _doubleTapLikeCountOverride;
  bool _isSeeking = false;
  Offset? _doubleTapPosition;
  final List<_FloatingHeartEffect> _floatingHearts = [];

  VideoPlayerController? _videoController;
  SubtitleCue? _activeSubtitle;

  bool get _showSubtitles => _subtitleMode != SubtitleMode.off;

  void _cycleSubtitleMode() {
    setState(() {
      _subtitleMode = switch (_subtitleMode) {
        SubtitleMode.bilingual => SubtitleMode.japaneseOnly,
        SubtitleMode.japaneseOnly => SubtitleMode.off,
        SubtitleMode.off => SubtitleMode.bilingual,
      };
    });
  }

  /// Đổi giá trị này để dựng lại VideoPlayer sau khi màn Kịch bản (dùng chung
  /// controller) đóng lại, tránh khung video bị đen.
  int _playerEpoch = 0;

  Future<void> _openScript() async {
    RubySubtitleWidget.dismissLookups();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VideoScriptScreen(
          cues: widget.post.subtitleCues,
          controller: _videoController,
          initialBilingual: _subtitleMode == SubtitleMode.bilingual,
          videoId: widget.post.id,
        ),
      ),
    );
    if (mounted) setState(() => _playerEpoch++);
  }

  /// null khi video không có thông tin người đăng (không mở được trang cá nhân).
  VoidCallback? get _onCreatorTap =>
      widget.post.creatorId == null ? null : _openCreatorProfile;

  void _openTopic(TopicModel topic) {
    _openSimilarVideos(ExploreScreen(showBackButton: true, initialTopicId: topic.id));
  }

  void _openHashtag(String hashtag) {
    _openSimilarVideos(ExploreScreen(showBackButton: true, initialSearch: '#$hashtag'));
  }

  /// Mở danh sách video cùng chủ đề / hashtag. Video tạm dừng trong lúc xem rồi phát tiếp.
  Future<void> _openSimilarVideos(ExploreScreen screen) async {
    RubySubtitleWidget.dismissLookups();
    final controller = _videoController;
    final wasPlaying = controller != null && controller.value.isPlaying;
    if (controller != null && wasPlaying) await controller.pause();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(backgroundColor: AppPalette.background, body: screen),
      ),
    );
    if (!mounted) return;
    if (controller != null && wasPlaying && identical(controller, _videoController)) {
      await controller.play();
    }
  }

  /// Mở trang cá nhân của người đăng. Video tạm dừng trong lúc xem rồi phát tiếp,
  /// để không còn tiếng phát ở phía sau.
  Future<void> _openCreatorProfile() async {
    final creatorId = widget.post.creatorId;
    if (creatorId == null) return;
    if (!await requireAuthentication(
      context,
      message: 'Vui lòng đăng nhập để xem trang cá nhân.',
    )) {
      return;
    }
    if (!mounted) return;
    RubySubtitleWidget.dismissLookups();
    final controller = _videoController;
    final wasPlaying = controller != null && controller.value.isPlaying;
    if (controller != null && wasPlaying) await controller.pause();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(
          userId: creatorId,
          initialName: widget.post.creatorName,
          onFollowChanged: widget.onCreatorFollowChanged,
        ),
      ),
    );
    if (controller != null &&
        wasPlaying &&
        mounted &&
        _playbackAllowed &&
        identical(controller, _videoController) &&
        controller.value.isInitialized) {
      controller.play().catchError((error) {
        debugPrint('Video playback failed: $error');
      });
    }
  }

  /// Chia sẻ video cho bạn bè (follow lẫn nhau). Mốc thời gian gợi ý là câu phụ
  /// đề đang hiển thị, nếu không có thì là vị trí đang phát.
  Future<void> _handleShare() async {
    if (!await requireAuthentication(
      context,
      message: 'Vui lòng đăng nhập để chia sẻ video cho bạn bè.',
    )) {
      return;
    }
    if (!mounted) return;
    await showShareVideoSheet(
      context,
      videoId: widget.post.id,
    );
  }

  void _handleDoubleTapDown(TapDownDetails details) {
    _doubleTapPosition = details.localPosition;
  }

  Future<void> _handleDoubleTap() async {
    if (!AuthSession.instance.isAuthenticated) {
      await requireAuthentication(
        context,
        message: 'Vui lòng đăng nhập để thả tim video này.',
      );
      return;
    }

    final isLiked = _doubleTapLikedOverride ?? widget.post.isLiked;
    final likeCount = _doubleTapLikeCountOverride ?? widget.post.likeCount;

    if (!isLiked) {
      _doubleTapLikedOverride = true;
      _doubleTapLikeCountOverride = likeCount + 1;
      widget.onLikeToggle?.call();
    }

    final position = _doubleTapPosition;
    if (position == null || !mounted) return;

    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    final effect = _FloatingHeartEffect(
      position: position,
      controller: controller,
    );
    setState(() => _floatingHearts.add(effect));
    controller.forward();
    controller.addStatusListener((status) {
      if (status != AnimationStatus.completed || !mounted) return;
      setState(() => _floatingHearts.remove(effect));
      controller.dispose();
    });
  }

  Widget _buildFloatingHearts() {
    return IgnorePointer(
      child: Stack(
        children: [
          for (final effect in _floatingHearts)
            Positioned(
              left: effect.position.dx - 48,
              top: effect.position.dy - 48,
              child: FadeTransition(
                opacity: TweenSequence<double>([
                  TweenSequenceItem(tween: ConstantTween(1.0), weight: 55),
                  TweenSequenceItem(
                    tween: Tween(begin: 1.0, end: 0.0),
                    weight: 45,
                  ),
                ]).animate(effect.controller),
                child: ScaleTransition(
                  scale: TweenSequence<double>([
                    TweenSequenceItem(
                      tween: Tween(begin: 0.5, end: 1.2),
                      weight: 35,
                    ),
                    TweenSequenceItem(
                      tween: Tween(begin: 1.2, end: 1.0),
                      weight: 25,
                    ),
                    TweenSequenceItem(tween: ConstantTween(1.0), weight: 40),
                  ]).animate(effect.controller),
                  child: const Icon(
                    Icons.favorite,
                    color: AppColors.likeRed,
                    size: 96,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    widget.playbackAllowed?.addListener(_onPlaybackAllowedChanged);
    appVideoPlaybackAllowed.addListener(_onPlaybackAllowedChanged);
    _initializeVideo();
  }

  @override
  void dispose() {
    widget.playbackAllowed?.removeListener(_onPlaybackAllowedChanged);
    appVideoPlaybackAllowed.removeListener(_onPlaybackAllowedChanged);
    for (final effect in _floatingHearts) {
      effect.controller.dispose();
    }
    _videoController?.dispose();
    super.dispose();
  }

  bool get _playbackAllowed => widget.playbackAllowed?.value ?? true;
  bool get _canAutoPlay =>
      _playbackAllowed && appVideoPlaybackAllowed.value && widget.isActive;

  /// Video bị dừng vì không còn hiện trên màn hình (không phải người dùng bấm dừng).
  bool _pausedForHidden = false;

  /// Feed bị che / chuyển tab: dừng hẳn video (không phát và giải mã ngầm phía sau);
  /// hiện lại thì phát tiếp nếu chính việc bị che đã làm nó dừng.
  void _onPlaybackAllowedChanged() {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;
    if (!_canAutoPlay) {
      if (controller.value.isPlaying) {
        _pausedForHidden = true;
        controller.pause();
      }
    } else if (_pausedForHidden) {
      _pausedForHidden = false;
      _isMutedForWebAutoplay = false;
      controller.setVolume(1).then((_) => controller.play()).catchError(
        (error) {
          debugPrint('Video playback failed: $error');
        },
      );
    }
  }

  @override
  void didUpdateWidget(covariant VideoPlayerItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playbackAllowed != widget.playbackAllowed) {
      oldWidget.playbackAllowed?.removeListener(_onPlaybackAllowedChanged);
      widget.playbackAllowed?.addListener(_onPlaybackAllowedChanged);
    }
    if (oldWidget.isActive != widget.isActive) {
      _onPlaybackAllowedChanged();
    }
    if (oldWidget.post.id != widget.post.id ||
        oldWidget.post.isLiked != widget.post.isLiked ||
        oldWidget.post.likeCount != widget.post.likeCount) {
      _doubleTapLikedOverride = null;
      _doubleTapLikeCountOverride = null;
    }
  }

  Future<void> _initializeVideo() async {
    final videoUrl = widget.post.videoUrl;
    if (videoUrl.isEmpty) return;

    final controller = VideoPlayerController.networkUrl(
      Uri.parse(videoUrl),
      videoPlayerOptions: VideoPlayerOptions(
        webOptions: const VideoPlayerWebOptions(
          controls: VideoPlayerWebOptionsControls.disabled(),
          allowContextMenu: false,
          allowRemotePlayback: false,
        ),
      ),
    );
    _videoController = controller;
    try {
      await controller.initialize();
      await controller.setLooping(true);
      // Trình duyệt chặn autoplay có tiếng. Video đầu tiên cần chạy mute;
      // lần chạm đầu tiên hoặc thao tác vuốt sẽ mở tiếng trở lại.
      _isMutedForWebAutoplay = kIsWeb && widget.isActive;
      await controller.setVolume(
        widget.isActive && !kIsWeb ? 1 : 0,
      );
      final startAt = widget.initialPosition;
      if (startAt != null && startAt < controller.value.duration) {
        await controller.seekTo(startAt);
      }
      controller.addListener(_updateActiveSubtitle);
      if (!mounted || _videoController != controller) return;
      setState(() {});
      _updateActiveSubtitle();

      // Tải xong khi feed đang bị che: chờ hiện lại mới phát.
      if (!_canAutoPlay) {
        _pausedForHidden = true;
        return;
      }

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
    SubtitleCue? active;
    for (final cue in widget.post.subtitleCues) {
      if (cue.contains(position)) {
        active = cue;
        break;
      }
    }

    // Chỉ dựng lại khi đổi câu phụ đề / trạng thái phát. Vị trí phát đổi liên tục
    // nên thanh tiến trình tự lắng nghe controller (xem _buildProgressFill).
    final isPlaying = controller.value.isPlaying;
    if (active?.start != _activeSubtitle?.start ||
        active?.end != _activeSubtitle?.end ||
        isPlaying != _isPlaying) {
      setState(() {
        _activeSubtitle = active;
        _isPlaying = isPlaying;
      });
    }
  }

  /// Phần đã phát của thanh tiến trình. Chỉ widget này dựng lại theo vị trí phát,
  /// không kéo theo cả video item (phụ đề, sidebar, ảnh đại diện...).
  Widget _buildProgressFill(Widget Function(double progress) builder) {
    final controller = _videoController;
    if (controller == null) return builder(0.0);
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final total = value.duration.inMilliseconds;
        final progress = total > 0
            ? (value.position.inMilliseconds / total).clamp(0.0, 1.0)
            : 0.0;
        return builder(progress);
      },
    );
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

  /// Tạm dừng video khi người dùng tra từ trong phụ đề, phát tiếp khi xong
  /// (chỉ phát tiếp nếu chính việc tra từ đã làm video dừng).
  bool _pausedForLookup = false;

  void _handleLookupActiveChanged(bool active) {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;

    if (active) {
      if (controller.value.isPlaying) {
        _pausedForLookup = true;
        controller.pause();
      }
    } else if (_pausedForLookup) {
      _pausedForLookup = false;
      if (_isPlaying && mounted && _canAutoPlay) {
        controller.play().catchError((error) {
          debugPrint('Video playback failed: $error');
        });
      }
    }
  }

  void _handleTapToPlayPause() {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    if (controller.value.isPlaying && _isMutedForWebAutoplay) {
      _isMutedForWebAutoplay = false;
      controller.setVolume(1).catchError((error) {
        debugPrint('Video unmute failed: $error');
      });
      return;
    }

    final shouldPlay = !controller.value.isPlaying;
    setState(() => _isPlaying = shouldPlay);

    if (shouldPlay) {
      controller.setVolume(1);
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

  /// Khoảng cách từ mép trên thanh menu dưới tới đáy cột tương tác; đủ để né thanh tiến trình.
  /// Cả bố cục dọc lẫn ngang dùng chung để cột không nhảy vị trí khi video tải xong.
  static const double _sidebarBottomGap = 28.0;
  static const double _actionBarRightShift = 6.0;

  Widget _buildInteractionSidebar({
    required AdaptiveVideoTheme theme,
    required double bottom,
    required double width,
  }) {
    return Positioned(
      right: -_actionBarRightShift,
      bottom: bottom,
      width: width,
      child: Center(
        child: InteractionSidebar(
          post: widget.post,
          theme: theme,
          subtitleMode: _subtitleMode,
          isLikedOverride: _doubleTapLikedOverride,
          likeCountOverride: _doubleTapLikeCountOverride,
          onToggleSubtitles: _cycleSubtitleMode,
          onLikeToggle: widget.onLikeToggle,
          onSaveToggle: widget.onSaveToggle,
          onFollowToggle: widget.onFollowToggle,
          onCreatorTap: _onCreatorTap,
          onCommentTap: widget.onCommentTap,
          onShareTap: _handleShare,
          onScriptTap: _openScript,
          allowAccountActions: widget.allowAccountActions,
        ),
      ),
    );
  }

  /// Chiều cao thanh menu dưới cần chừa (0 khi màn này không có thanh menu), chưa gồm vùng an toàn.
  double get _barHeight => widget.reserveBottomBar ? BottomNavDock.contentHeight : 0.0;

  @override
  Widget build(BuildContext context) {
    // Dynamic contrast theme based on background brightness
    final theme = AdaptiveVideoTheme(isLight: widget.post.isLightBackground);
    // Chiều cao thanh menu dưới (kể cả vùng an toàn) để các lớp phủ né ra.
    final navBarHeight =
        _barHeight + MediaQuery.paddingOf(context).bottom;
    final activeCue = _activeSubtitle;
    final displayedSegments = widget.post.subtitleCues.isEmpty
        ? widget.post.rubySegments
        : activeCue == null
        ? const <RubySegment>[]
        : [RubySegment(kanji: activeCue.text, furigana: '')];
    final displayedTranslation = widget.post.subtitleCues.isEmpty
        ? widget.post.translation
        : activeCue?.translation ?? '';

    if (_videoController?.value.isInitialized == true &&
        _videoController!.value.aspectRatio > 1.15) {
      return _buildLandscapeLayout(
        theme: theme,
        activeCue: activeCue,
        displayedSegments: displayedSegments,
        displayedTranslation: displayedTranslation,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final tabWidth = constraints.maxWidth / 5;
        return GestureDetector(
          onTap: _handleTapToPlayPause,
          behavior: HitTestBehavior.opaque,
          child: ColoredBox(
            color: AppPalette.videoScrim,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. Video căn giữa trên nền chính (#0A092D).
                _buildVideoBackground(theme),
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _handleTapToPlayPause,
                    onDoubleTapDown: _handleDoubleTapDown,
                    onDoubleTap: _handleDoubleTap,
                  ),
                ),
                _buildPlaybackOverlay(),

                // 2. Multi-tier Gradient Scrims
                // Top Scrim
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 180.0,
                  child: IgnorePointer(
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
                ),
                // Bottom Scrim chỉ phủ khu vực caption và thông tin uploader, không
                // lấn sâu xuống vùng navigation bar.
                Positioned(
                  bottom: navBarHeight,
                  left: 0,
                  right: 0,
                  height: MediaQuery.sizeOf(context).height * 0.28,
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            AppPalette.videoScrim.withValues(alpha: 0.50),
                            AppPalette.videoScrim.withValues(alpha: 0.25),
                            AppPalette.videoScrim.withValues(alpha: 0.08),
                            Colors.transparent,
                          ],
                          stops: [0.0, 0.34, 0.68, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),

                // 4. Cột tương tác bên phải, neo sát đáy (cùng vị trí với bố cục ngang)
                _buildInteractionSidebar(
                  theme: theme,
                  bottom: navBarHeight + _sidebarBottomGap,
                  width: tabWidth,
                ),
                Positioned.fill(child: _buildFloatingHearts()),

                // 5. Bottom Subtitle & Video Metadata Overlay
                Positioned(
                  left: 16.0,
                  right: 88.0,
                  bottom: navBarHeight + 10.0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_showSubtitles)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10.0),
                          child: RubySubtitleWidget(
                            rubySegments: displayedSegments,
                            translation: _subtitleMode == SubtitleMode.bilingual
                                ? displayedTranslation
                                : '',
                            theme: theme,
                            sentence: activeCue?.text,
                            grammarPoints: activeCue?.grammarPoints ?? const [],
                            onLookupActiveChanged: _handleLookupActiveChanged,
                          ),
                        ),
                      VideoInfoOverlay(
                        post: widget.post,
                        theme: theme,
                        onCreatorTap: _onCreatorTap,
                        onTopicTap: _openTopic,
                        onHashtagTap: _openHashtag,
                      ),
                    ],
                  ),
                ),

                // 6. Video Progress Scrubber Bar
                Positioned(
                  bottom: navBarHeight + 4.0,
                  left: 0,
                  right: 0,
                  child: SizedBox(
                    height: 22.0,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (details) => _seekToFraction(
                            (details.localPosition.dx / constraints.maxWidth)
                                .clamp(0.0, 1.0),
                          ),
                          onHorizontalDragUpdate: (details) => _seekToFraction(
                            (details.localPosition.dx / constraints.maxWidth)
                                .clamp(0.0, 1.0),
                          ),
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: SizedBox(
                              height: 3.0,
                              child: Stack(
                                children: [
                                  Container(color: theme.progressTrack),
                                  _buildProgressFill(
                                    (progress) => FractionallySizedBox(
                                      widthFactor: progress,
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
          ),
        );
      },
    );
  }

  Widget _buildLandscapeLayout({
    required AdaptiveVideoTheme theme,
    required SubtitleCue? activeCue,
    required List<RubySegment> displayedSegments,
    required String displayedTranslation,
  }) {
    return ColoredBox(
      color: AppPalette.videoScrim,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final mediaPadding = MediaQuery.paddingOf(context);
          final topReservedHeight = mediaPadding.top + 56.0;
          final bottomReservedHeight =
              _barHeight + mediaPadding.bottom;
          final contentHeight = math.max(
            0.0,
            constraints.maxHeight - topReservedHeight - bottomReservedHeight,
          );
          final videoWidth = constraints.maxWidth;
          final videoHeight = videoWidth / (16 / 9);
          final remainingHeight = math.max(0.0, contentHeight - videoHeight);
          final contentZoneHeight = math.min(220.0, remainingHeight);
          final tabWidth = constraints.maxWidth / 5;
          final topVideoSpacer = math.max(
            0.0,
            remainingHeight - contentZoneHeight,
          );

          return Stack(
            fit: StackFit.expand,
            children: [
              Column(
                children: [
                  SizedBox(height: topReservedHeight),
                  SizedBox(height: topVideoSpacer),
                  SizedBox(
                    width: videoWidth,
                    height: videoHeight,
                    child: GestureDetector(
                      onTap: _handleTapToPlayPause,
                      behavior: HitTestBehavior.opaque,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ColoredBox(
                            color: AppPalette.videoScrim,
                            child: VideoPlayer(
                              _videoController!,
                              key: ValueKey(_playerEpoch),
                            ),
                          ),
                          Positioned.fill(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: _handleTapToPlayPause,
                              onDoubleTapDown: _handleDoubleTapDown,
                              onDoubleTap: _handleDoubleTap,
                            ),
                          ),
                          Positioned.fill(child: _buildFloatingHearts()),
                          _buildPlaybackOverlay(),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    height: contentZoneHeight,
                    child: Container(
                      width: double.infinity,
                      color: AppPalette.videoScrim,
                      padding: const EdgeInsets.fromLTRB(16, 8, 78, 16),
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_showSubtitles)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: RubySubtitleWidget(
                                    rubySegments: displayedSegments,
                                    translation:
                                        _subtitleMode == SubtitleMode.bilingual
                                        ? displayedTranslation
                                        : '',
                                    theme: theme,
                                    sentence: activeCue?.text,
                                    grammarPoints:
                                        activeCue?.grammarPoints ?? const [],
                                    onLookupActiveChanged:
                                        _handleLookupActiveChanged,
                                  ),
                                ),
                              VideoInfoOverlay(
                                post: widget.post,
                                theme: theme,
                                onCreatorTap: _onCreatorTap,
                                onTopicTap: _openTopic,
                                onHashtagTap: _openHashtag,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: bottomReservedHeight),
                ],
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: bottomReservedHeight,
                child: _buildProgressBar(theme),
              ),
              _buildInteractionSidebar(
                theme: theme,
                bottom: bottomReservedHeight + _sidebarBottomGap,
                width: tabWidth,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProgressBar(AdaptiveVideoTheme theme) {
    return SizedBox(
      height: 12,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) {
              if (mounted) setState(() => _isSeeking = true);
              _seekToFraction(
                (details.localPosition.dx / constraints.maxWidth).clamp(
                  0.0,
                  1.0,
                ),
              );
            },
            onTapUp: (_) {
              if (mounted) setState(() => _isSeeking = false);
            },
            onTapCancel: () {
              if (mounted) setState(() => _isSeeking = false);
            },
            onHorizontalDragUpdate: (details) => _seekToFraction(
              (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0),
            ),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                height: _isSeeking ? 4 : 3,
                child: Stack(
                  children: [
                    Container(color: theme.progressTrack),
                    _buildProgressFill(
                      (progress) => FractionallySizedBox(
                        widthFactor: progress,
                        child: Container(color: theme.progressActive),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlaybackOverlay() {
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: true,
        child: AnimatedOpacity(
          opacity: _isPlaying ? 0.0 : 1.0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: Center(
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: AppPalette.videoScrim.withValues(alpha: 0.38),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.play_arrow_rounded,
                size: 64,
                color: AppPalette.onVideo,
              ),
            ),
          ),
        ),
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
            child: VideoPlayer(controller, key: ValueKey(_playerEpoch)),
          ),
        );
      }

      return ColoredBox(
        color: AppPalette.videoScrim,
        child: Center(
          child: AspectRatio(
            aspectRatio: aspectRatio,
            child: VideoPlayer(controller, key: ValueKey(_playerEpoch)),
          ),
        ),
      );
    }

    return _videoPlaceholder(theme);
  }

  Widget _videoPlaceholder(AdaptiveVideoTheme theme) {
    return Container(
      color: AppPalette.videoScrim,
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
