import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/theme/app_palette.dart';
import '../../domain/models/ruby_segment.dart';

/// Màn "Kịch bản": xem lại video kèm danh sách toàn bộ câu thoại theo thời gian.
/// Dùng chung [VideoPlayerController] với video đang xem, bấm một câu để tua tới.
class VideoScriptScreen extends StatefulWidget {
  final List<SubtitleCue> cues;
  final VideoPlayerController? controller;
  final bool initialBilingual;

  const VideoScriptScreen({
    super.key,
    required this.cues,
    required this.controller,
    this.initialBilingual = true,
  });

  @override
  State<VideoScriptScreen> createState() => _VideoScriptScreenState();
}

class _VideoScriptScreenState extends State<VideoScriptScreen> {
  static Color get _linkBlue => AppPalette.info;

  late bool _bilingual = widget.initialBilingual;
  late final List<GlobalKey> _itemKeys = List.generate(
    widget.cues.length,
    (_) => GlobalKey(),
  );
  int _lastActive = -1;

  VideoPlayerController? get _video {
    final c = widget.controller;
    return (c != null && c.value.isInitialized) ? c : null;
  }

  int _activeIndex(Duration position) {
    for (var i = 0; i < widget.cues.length; i++) {
      if (widget.cues[i].contains(position)) return i;
    }
    return -1;
  }

  String _format(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String _formatCue(Duration d) {
    final m = d.inMinutes.toString().padLeft(1, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _togglePlay() {
    final video = _video;
    if (video == null) return;
    if (video.value.isPlaying) {
      video.pause();
    } else {
      video.setVolume(1);
      video.play();
    }
  }

  void _seekTo(Duration position) {
    final video = _video;
    if (video == null) return;
    video.seekTo(position);
    if (!video.value.isPlaying) {
      video.setVolume(1);
      video.play();
    }
  }

  void _seekFraction(double fraction) {
    final video = _video;
    if (video == null) return;
    final total = video.value.duration.inMilliseconds;
    video.seekTo(Duration(milliseconds: (total * fraction).round()));
  }

  void _scrollToActive(int index) {
    if (index < 0 || index == _lastActive) return;
    _lastActive = index;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _itemKeys[index].currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        alignment: 0.3,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Scaffold(
      backgroundColor: AppPalette.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            if (controller == null)
              _buildVideoArea(null)
            else
              ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: controller,
                builder: (context, value, _) => _buildVideoArea(value),
              ),
            Expanded(
              child: controller == null
                  ? _buildList(-1)
                  : ValueListenableBuilder<VideoPlayerValue>(
                      valueListenable: controller,
                      builder: (context, value, _) {
                        final active = _activeIndex(value.position);
                        _scrollToActive(active);
                        return _buildList(active);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return SizedBox(
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: AppPalette.textPrimary,
              ),
            ),
          ),
          Text(
            'Kịch bản',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppPalette.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoArea(VideoPlayerValue? value) {
    final video = _video;
    final initialized = value?.isInitialized ?? false;
    final position = initialized ? value!.position : Duration.zero;
    final duration = initialized ? value!.duration : Duration.zero;
    final fraction = duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;
    final playing = initialized && value!.isPlaying;

    return Column(
      children: [
        GestureDetector(
          onTap: _togglePlay,
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: 190,
            width: double.infinity,
            color: AppPalette.surface,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (video != null)
                  Center(
                    child: AspectRatio(
                      aspectRatio: video.value.aspectRatio,
                      child: VideoPlayer(video),
                    ),
                  ),
                AnimatedOpacity(
                  opacity: playing ? 0 : 1,
                  duration: const Duration(milliseconds: 150),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppPalette.textSecondary.withValues(alpha: 0.40),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.play_arrow_rounded,
                      size: 34,
                      color: AppPalette.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) =>
                _seekFraction(d.localPosition.dx / constraints.maxWidth),
            onHorizontalDragUpdate: (d) => _seekFraction(
              (d.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0),
            ),
            child: SizedBox(
              height: 12,
              child: Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  height: 3,
                  child: Stack(
                    children: [
                      Container(color: AppPalette.border),
                      FractionallySizedBox(
                        widthFactor: fraction,
                        child: Container(color: _linkBlue),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              Text(
                '${_format(position)} / ${_format(duration)}',
                style: TextStyle(
                  fontSize: 13,
                  color: AppPalette.textSecondary,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _bilingual = !_bilingual),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    _bilingual ? 'Song ngữ' : 'Tiếng Nhật',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _linkBlue,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildList(int activeIndex) {
    if (widget.cues.isEmpty) {
      return Center(
        child: Text(
          'Video này chưa có kịch bản',
          style: TextStyle(color: AppPalette.textSecondary, fontSize: 14),
        ),
      );
    }

    return Scrollbar(
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: widget.cues.length,
        itemBuilder: (context, i) {
          final cue = widget.cues[i];
          final isActive = i == activeIndex;
          return InkWell(
            key: _itemKeys[i],
            onTap: () => _seekTo(cue.start),
            child: Container(
              padding: const EdgeInsets.fromLTRB(13, 14, 16, 14),
              decoration: BoxDecoration(
                color: isActive ? AppPalette.surface : Colors.transparent,
                border: Border(
                  left: BorderSide(
                    color: isActive ? _linkBlue : Colors.transparent,
                    width: 3,
                  ),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 48,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        _formatCue(cue.start),
                        style: TextStyle(
                          fontSize: 13,
                          color: isActive
                              ? _linkBlue
                              : AppPalette.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cue.text,
                          style: TextStyle(
                            fontSize: 17,
                            height: 1.35,
                            fontWeight: isActive
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isActive
                                ? AppPalette.textPrimary
                                : AppPalette.textSecondary,
                          ),
                        ),
                        if (_bilingual && cue.translation.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            cue.translation,
                            style: TextStyle(
                              fontSize: 13.5,
                              height: 1.3,
                              fontWeight: isActive
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: isActive
                                  ? AppPalette.textPrimary
                                  : AppPalette.textSecondary.withValues(
                                      alpha: 0.8,
                                    ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
