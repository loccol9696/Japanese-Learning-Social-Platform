import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/auth/auth_guard.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../auth/data/auth_session.dart';
import '../../data/services/shadowing_service.dart';
import '../../domain/models/ruby_segment.dart';
import '../widgets/lookup_sentence_text.dart';
import '../widgets/ruby_subtitle_widget.dart';
import 'dictation_sheet.dart';
import 'shadowing_sheet.dart';

/// Chiều cao khung video ở màn Kịch bản: vừa khít video theo tỉ lệ thật ([aspectRatio] = rộng / cao), nên video
/// ngang không bị chừa khoảng trống trên dưới. Chưa biết tỉ lệ (video chưa tải) thì tạm dùng 16:9. Video dọc hoặc
/// vuông cao hơn 42% chiều cao màn sẽ bị chặn ở mức đó để danh sách câu thoại bên dưới vẫn còn chỗ xem.
double scriptVideoHeight(Size screen, {double? aspectRatio}) {
  final ratio = (aspectRatio != null && aspectRatio > 0) ? aspectRatio : 16 / 9;
  return math.min(screen.width / ratio, screen.height * 0.42);
}

/// Màn "Kịch bản": xem lại video kèm danh sách toàn bộ câu thoại theo thời gian.
/// Dùng chung [VideoPlayerController] với video đang xem, bấm một câu để tua tới.
class VideoScriptScreen extends StatefulWidget {
  final List<SubtitleCue> cues;
  final VideoPlayerController? controller;
  final bool initialBilingual;

  /// Id video (số) để chấm điểm luyện nói; null thì ẩn nút micro.
  final String? videoId;

  const VideoScriptScreen({
    super.key,
    required this.cues,
    required this.controller,
    this.initialBilingual = true,
    this.videoId,
  });

  @override
  State<VideoScriptScreen> createState() => _VideoScriptScreenState();
}

class _VideoScriptScreenState extends State<VideoScriptScreen> {
  static Color get _linkBlue => AppPalette.info;
  static const Color _inactiveText = Color(0xFFA9B0C9);
  static const Color _inactiveTranslation = Color(0xFF7B83A3);
  final ScrollController _listController = ScrollController();

  late bool _bilingual = widget.initialBilingual;
  late final List<GlobalKey> _itemKeys = List.generate(
    widget.cues.length,
    (_) => GlobalKey(),
  );
  int _lastActive = -1;

  /// lineIndex -> điểm cao nhất của người dùng.
  Map<int, int> _bestScores = {};
  final Map<int, int> _bestDictationScores = {};

  bool get _canPractice =>
      widget.videoId != null && int.tryParse(widget.videoId!) != null;

  @override
  void initState() {
    super.initState();
    _loadBestScores();
    _loadDictationScores();
  }

  @override
  void dispose() {
    _listController.dispose();
    super.dispose();
  }

  Future<void> _loadBestScores() async {
    if (!_canPractice || !AuthSession.instance.isAuthenticated) return;
    try {
      final summary = await ShadowingService.instance.summary(widget.videoId!);
      if (mounted) setState(() => _bestScores = summary.bestScores);
    } catch (_) {
      // Không có huy hiệu điểm nếu không lấy được; không ảnh hưởng việc xem kịch bản.
    }
  }

  String get _dictationScoreKey =>
      'dictation_scores_${widget.videoId ?? 'local'}';

  Future<void> _loadDictationScores() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_dictationScoreKey);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final scores = <int, int>{
        for (final entry in decoded.entries)
          if (int.tryParse(entry.key) != null && entry.value is num)
            int.parse(entry.key): (entry.value as num).toInt(),
      };
      if (mounted) setState(() => _bestDictationScores.addAll(scores));
    } catch (_) {
      // Dữ liệu cũ hỏng thì bỏ qua, lần chấm tiếp theo sẽ ghi lại.
    }
  }

  Future<void> _saveDictationScores() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _dictationScoreKey,
      jsonEncode(_bestDictationScores.map((key, value) => MapEntry('$key', value))),
    );
  }

  Future<void> _openShadowing(int index) async {
    final ok = await requireAuthentication(
      context,
      message: 'Bạn cần đăng nhập để luyện nói và lưu điểm.',
    );
    if (!ok || !mounted) return;
    widget.controller?.pause();
    // Mở ngay trên màn Kịch bản dưới dạng bảng; điểm mới được báo về từng lần chấm xong.
    await showShadowingSheet(
      context,
      videoId: widget.videoId!,
      cues: widget.cues,
      startIndex: index,
      videoController: widget.controller,
      bestScores: _bestScores,
      onScoresChanged: (scores) {
        if (mounted) setState(() => _bestScores = Map<int, int>.of(scores));
      },
    );
  }

  Future<void> _openDictation(int index) async {
    final ok = await requireAuthentication(
      context,
      message: 'Bạn cần đăng nhập để luyện nghe và viết.',
    );
    if (!ok || !mounted) return;
    widget.controller?.pause();
    await showDictationSheet(
      context,
      cues: widget.cues,
      startIndex: index,
      videoController: widget.controller,
      onScore: (lineIndex, score) {
        final previous = _bestDictationScores[lineIndex] ?? 0;
        if (score > previous && mounted) {
          setState(() => _bestDictationScores[lineIndex] = score);
          _saveDictationScores();
        }
      },
    );
  }

  Color _scoreColor(int score) {
    if (score >= 85) return const Color(0xFF34D399);
    if (score >= 70) return _linkBlue;
    return const Color(0xFFFF9F43);
  }

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
                Icons.chevron_left_rounded,
                size: 30,
                color: AppPalette.textPrimary,
              ),
              tooltip: 'Quay lại',
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
            key: const ValueKey('script-video-area'),
            height: scriptVideoHeight(
              MediaQuery.sizeOf(context),
              aspectRatio: (video != null && initialized) ? video.value.aspectRatio : null,
            ),
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
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      color: Color(0xFF2C3068),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.play_arrow_rounded,
                      size: 42,
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

    // Cuộn danh sách làm bảng tra từ lệch khỏi từ được chạm, nên đóng bảng khi bắt đầu cuộn.
    return NotificationListener<ScrollStartNotification>(
      onNotification: (_) {
        RubySubtitleWidget.dismissLookups();
        return false;
      },
      child: Scrollbar(
      controller: _listController,
      thumbVisibility: true,
      thickness: 5,
      radius: const Radius.circular(3),
      child: ListView.builder(
        controller: _listController,
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
                        LookupSentenceText(
                          sentence: cue.text,
                          grammarPoints: cue.grammarPoints,
                          // Tra từ thì tạm dừng video để đọc bảng nghĩa, giống phụ đề ở trang chủ.
                          onLookupActiveChanged: (active) {
                            if (active) widget.controller?.pause();
                          },
                          style: TextStyle(
                            fontSize: 17,
                            height: 1.35,
                            fontWeight: isActive
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isActive
                                ? AppPalette.textPrimary
                                : _inactiveText,
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
                                  : _inactiveTranslation,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (_canPractice)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () => _openShadowing(i),
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(10, 2, 6, 2),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.mic_none_rounded,
                                  size: 22,
                                  color: isActive ? _linkBlue : AppPalette.textSecondary,
                                ),
                                if (_bestScores[i] != null)
                                  Text(
                                    '${_bestScores[i]}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: _scoreColor(_bestScores[i]!),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () => _openDictation(i),
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(6, 4, 0, 4),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.edit_outlined,
                                  size: 22,
                                  color: isActive
                                      ? _linkBlue
                                      : AppPalette.textSecondary,
                                ),
                                if (_bestDictationScores[i] != null)
                                  Text(
                                    '${_bestDictationScores[i]}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: _scoreColor(
                                        _bestDictationScores[i]!,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          );
        },
      ),
      ),
    );
  }
}
