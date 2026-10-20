import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/theme/adaptive_video_theme.dart';
import '../../domain/models/video_post.dart';
import '../../domain/models/ruby_segment.dart';
import 'bottom_nav_dock.dart';
import 'interaction_sidebar.dart';
import 'ruby_subtitle_widget.dart';
import 'video_info_overlay.dart';

class VideoPlayerItem extends StatefulWidget {
  final VideoPost post;
  final VoidCallback? onLikeToggle;
  final VoidCallback? onSaveToggle;
  final VoidCallback? onFollowToggle;
  final bool allowAccountActions;

  const VideoPlayerItem({
    super.key,
    required this.post,
    this.onLikeToggle,
    this.onSaveToggle,
    this.onFollowToggle,
    this.allowAccountActions = true,
  });

  @override
  State<VideoPlayerItem> createState() => _VideoPlayerItemState();
}

class _VideoPlayerItemState extends State<VideoPlayerItem> {
  bool _isPlaying = true;
  bool _showSubtitles = true;
  bool _isSeeking = false;
  double _videoProgress = 0.0;

  VideoPlayerController? _videoController;
  SubtitleCue? _activeSubtitle;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
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
      await controller.setVolume(0);
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
    final isPlaying = controller.value.isPlaying;
    if (active?.start != _activeSubtitle?.start ||
        active?.end != _activeSubtitle?.end ||
        progress != _videoProgress ||
        isPlaying != _isPlaying) {
      setState(() {
        _activeSubtitle = active;
        _videoProgress = progress;
        _isPlaying = isPlaying;
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
      if (_isPlaying && mounted) {
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

  @override
  Widget build(BuildContext context) {
    // Dynamic contrast theme based on background brightness
    final theme = AdaptiveVideoTheme(isLight: widget.post.isLightBackground);
    // Chiều cao thanh menu dưới (kể cả vùng an toàn) để các lớp phủ né ra.
    final navBarHeight =
        BottomNavDock.contentHeight + MediaQuery.paddingOf(context).bottom;
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

    return GestureDetector(
      onTap: _handleTapToPlayPause,
      behavior: HitTestBehavior.opaque,
      child: ColoredBox(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Centered video on a solid black background.
            _buildVideoBackground(theme),
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _handleTapToPlayPause,
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
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Color(0x80000000),
                        Color(0x40000000),
                        Color(0x14000000),
                        Colors.transparent,
                      ],
                      stops: [0.0, 0.34, 0.68, 1.0],
                    ),
                  ),
                ),
              ),
            ),

            // 4. Right Side Interaction Sidebar (căn giữa theo chiều dọc)
            Positioned(
              right: 12.0,
              top: 0,
              bottom: 0,
              child: Center(
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
                  onSaveToggle: widget.onSaveToggle,
                  onFollowToggle: widget.onFollowToggle,
                  allowAccountActions: widget.allowAccountActions,
                ),
              ),
            ),

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
                        translation: displayedTranslation,
                        theme: theme,
                        sentence: activeCue?.text,
                        onLookupActiveChanged: _handleLookupActiveChanged,
                      ),
                    ),
                  VideoInfoOverlay(post: widget.post, theme: theme),
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
      ),
    );
  }

  Widget _buildLandscapeLayout({
    required AdaptiveVideoTheme theme,
    required SubtitleCue? activeCue,
    required List<RubySegment> displayedSegments,
    required String displayedTranslation,
  }) {
    return ColoredBox(
      color: Colors.black,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final mediaPadding = MediaQuery.paddingOf(context);
          final topReservedHeight = mediaPadding.top + 56.0;
          final bottomReservedHeight =
              BottomNavDock.contentHeight + mediaPadding.bottom;
          final contentHeight = math.max(
            0.0,
            constraints.maxHeight - topReservedHeight - bottomReservedHeight,
          );
          final videoWidth = constraints.maxWidth;
          final videoHeight = videoWidth / (16 / 9);
          final remainingHeight = math.max(0.0, contentHeight - videoHeight);
          final contentZoneHeight = math.min(220.0, remainingHeight);
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
                            color: Colors.black,
                            child: VideoPlayer(_videoController!),
                          ),
                          Positioned.fill(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: _handleTapToPlayPause,
                            ),
                          ),
                          _buildPlaybackOverlay(),
                          Positioned(
                            right: 12,
                            bottom: 20,
                            child: SizedBox(
                              width: 58,
                              height: math.max(0.0, videoHeight - 20),
                              child: FittedBox(
                                fit: BoxFit.contain,
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
                                  onSaveToggle: widget.onSaveToggle,
                                  onFollowToggle: widget.onFollowToggle,
                                  allowAccountActions:
                                      widget.allowAccountActions,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    height: contentZoneHeight,
                    child: Container(
                      width: double.infinity,
                      color: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Column(
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.bottomLeft,
                              child: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (_showSubtitles)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 10,
                                        ),
                                        child: RubySubtitleWidget(
                                          rubySegments: displayedSegments,
                                          translation: displayedTranslation,
                                          theme: theme,
                                          sentence: activeCue?.text,
                                          onLookupActiveChanged:
                                              _handleLookupActiveChanged,
                                        ),
                                      ),
                                    VideoInfoOverlay(
                                      post: widget.post,
                                      theme: theme,
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
                  SizedBox(height: bottomReservedHeight),
                ],
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: bottomReservedHeight,
                child: _buildProgressBar(theme),
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
                    FractionallySizedBox(
                      widthFactor: _videoProgress,
                      child: Container(color: theme.progressActive),
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
                color: Colors.black38,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                size: 64,
                color: Colors.white,
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
            child: VideoPlayer(controller),
          ),
        );
      }

      return ColoredBox(
        color: Colors.black,
        child: Center(
          child: AspectRatio(
            aspectRatio: aspectRatio,
            child: VideoPlayer(controller),
          ),
        ),
      );
    }

    return _videoPlaceholder(theme);
  }

  Widget _videoPlaceholder(AdaptiveVideoTheme theme) {
    return Container(
      color: Colors.black,
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
