import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart' show mapEquals;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/services/tts_service.dart';
import '../../../../core/theme/app_palette.dart';
import '../../data/services/shadowing_service.dart';
import '../../data/services/speech_recognizer.dart';
import '../../domain/models/ruby_segment.dart';
import '../../domain/models/shadowing_models.dart';
import '../controllers/shadowing_controller.dart';

/// Mở bảng "Luyện nói theo" từ dưới lên, phủ lên màn Kịch bản (không chuyển sang trang khác).
/// [onScoresChanged] nhận điểm cao nhất từng dòng mỗi khi có thay đổi, kể cả khi người dùng đóng bảng bằng cách
/// kéo xuống hoặc chạm ra ngoài.
Future<void> showShadowingSheet(
  BuildContext context, {
  required String videoId,
  required List<SubtitleCue> cues,
  int startIndex = 0,
  VideoPlayerController? videoController,
  Map<int, int> bestScores = const {},
  ValueChanged<Map<int, int>>? onScoresChanged,
  SpeechRecognizer? recognizer,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ShadowingSheet(
      videoId: videoId,
      cues: cues,
      startIndex: startIndex,
      videoController: videoController,
      bestScores: bestScores,
      onScoresChanged: onScoresChanged,
      recognizer: recognizer,
    ),
  );
}

/// Bảng "Luyện nói theo": nghe mẫu → nói theo → chấm điểm từng dòng phụ đề.
class ShadowingSheet extends StatefulWidget {
  final String videoId;
  final List<SubtitleCue> cues;
  final int startIndex;
  final VideoPlayerController? videoController;
  final Map<int, int> bestScores;

  /// Gọi mỗi khi điểm cao nhất của một dòng thay đổi.
  final ValueChanged<Map<int, int>>? onScoresChanged;

  /// Dùng khi kiểm thử để thay bộ nhận dạng giọng nói thật.
  final SpeechRecognizer? recognizer;

  const ShadowingSheet({
    super.key,
    required this.videoId,
    required this.cues,
    this.startIndex = 0,
    this.videoController,
    this.bestScores = const {},
    this.onScoresChanged,
    this.recognizer,
  });

  @override
  State<ShadowingSheet> createState() => _ShadowingSheetState();
}

class _ShadowingSheetState extends State<ShadowingSheet> {
  static const Color _linkBlue = Color(0xFF38BDF8);
  static const Color _wrongRed = Color(0xFFFF6B6B);

  late final ShadowingController _controller;
  late Map<int, int> _reportedScores;

  @override
  void initState() {
    super.initState();
    _reportedScores = Map<int, int>.of(widget.bestScores);
    _controller = ShadowingController(
      cues: widget.cues,
      recognizer: widget.recognizer ?? DeviceSpeechRecognizer(),
      startIndex: widget.startIndex,
      bestScores: widget.bestScores,
      playSample: _playSample,
      scoreLine: (index, text) => ShadowingService.instance.scoreLine(
        videoId: widget.videoId,
        lineIndex: index,
        recognizedText: text,
      ),
    );
    _controller.addListener(_reportScores);
  }

  /// Báo điểm mới cho màn bên dưới khi có thay đổi (không phụ thuộc cách đóng bảng).
  void _reportScores() {
    final current = _controller.bestScores;
    if (mapEquals(current, _reportedScores)) return;
    _reportedScores = Map<int, int>.of(current);
    widget.onScoresChanged?.call(current);
  }

  @override
  void dispose() {
    _controller.removeListener(_reportScores);
    TtsService.stop();
    final video = widget.videoController;
    if (video != null && video.value.isInitialized) {
      video.pause();
    }
    _controller.dispose();
    super.dispose();
  }

  /// Phát lại đúng đoạn của câu trong video (dư 0,2 giây hai đầu); không có video thì đọc bằng giọng máy.
  Future<void> _playSample(SubtitleCue cue) async {
    final video = widget.videoController;
    if (video != null && video.value.isInitialized) {
      const pad = Duration(milliseconds: 200);
      final start = cue.start > pad ? cue.start - pad : Duration.zero;
      final end = cue.end + pad;

      final done = Completer<void>();
      void listener() {
        if (video.value.position >= end && !done.isCompleted) done.complete();
      }

      video.addListener(listener);
      try {
        await video.seekTo(start);
        await video.setVolume(1);
        await video.play();
        await done.future.timeout(
          (end - start) + const Duration(seconds: 3),
          onTimeout: () {},
        );
      } finally {
        video.removeListener(listener);
        await video.pause();
      }
      return;
    }

    final done = Completer<void>();
    TtsService.speak(
      text: cue.text,
      lang: 'ja-JP',
      rate: 0.9,
      onComplete: () {
        if (!done.isCompleted) done.complete();
      },
    );
    await done.future.timeout(const Duration(seconds: 12), onTimeout: () {});
  }

  @override
  Widget build(BuildContext context) {
    // Cao khoảng 68% màn hình (không quá 580) để vẫn thấy video của màn Kịch bản phía trên.
    final height = min(MediaQuery.sizeOf(context).height * 0.68, 580.0);
    return SizedBox(
      height: height,
      child: Material(
        color: AppPalette.navBar,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              final summary = _controller.phase == ShadowingPhase.summary;
              return Column(
                children: [
                  _buildHeader(
                    summary ? 'Kết quả luyện nói' : 'Luyện nói theo',
                  ),
                  Expanded(child: summary ? _buildSummary() : _buildPractice()),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------ luyện tập

  /// Tay kéo + tiêu đề bên trái + nút đóng bên phải.
  Widget _buildHeader(String title) {
    return Column(
      children: [
        const SizedBox(height: 10),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: AppPalette.textPrimary.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 8, 0),
          child: Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  color: AppPalette.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              IconButton(
                key: const ValueKey('shadowing-close'),
                onPressed: () => Navigator.of(context).maybePop(),
                icon: Icon(Icons.close_rounded, color: AppPalette.textPrimary),
                tooltip: 'Đóng',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPractice() {
    final c = _controller;
    final cue = c.cue;
    if (cue == null) {
      return Center(
        child: Text(
          'Video này chưa có kịch bản để luyện nói',
          style: TextStyle(color: AppPalette.textSecondary),
        ),
      );
    }

    final busy =
        c.phase == ShadowingPhase.listening ||
        c.phase == ShadowingPhase.scoring ||
        c.phase == ShadowingPhase.playingSample;

    // Cuộn được khi nội dung dài (lỗi nhiều dòng, màn thấp); đủ chỗ thì vẫn dàn đều bằng Spacer.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(child: _buildPracticeColumn(cue, busy)),
        ),
      ),
    );
  }

  Widget _buildPracticeColumn(SubtitleCue cue, bool busy) {
    return Column(
      children: [
        const Spacer(flex: 2),
        _buildSentence(cue),
        const SizedBox(height: 8),
        if (cue.translation.isNotEmpty)
          Text(
            cue.translation,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppPalette.textSecondary, fontSize: 14),
          ),
        const SizedBox(height: 16),
        _buildSampleButton(busy),
        const Spacer(flex: 2),
        _buildWaveform(),
        const SizedBox(height: 14),
        _buildBottomControls(),
        const SizedBox(height: 22),
      ],
    );
  }

  /// Câu gốc; sau khi chấm, từ nói sai được tô đỏ.
  Widget _buildSentence(SubtitleCue cue) {
    final style = TextStyle(
      color: AppPalette.textPrimary,
      fontSize: 22,
      fontWeight: FontWeight.w800,
      height: 1.4,
    );
    final result = _controller.result;
    if (_controller.phase != ShadowingPhase.result || result == null) {
      return Text(cue.text, textAlign: TextAlign.center, style: style);
    }
    return Text.rich(
      TextSpan(
        children: [
          for (final word in result.words)
            TextSpan(
              text: word.text,
              style: style.copyWith(
                color: word.correct ? AppPalette.textPrimary : _wrongRed,
              ),
            ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildSampleButton(bool busy) {
    final playing = _controller.phase == ShadowingPhase.playingSample;
    return Material(
      color: AppPalette.background,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        key: const ValueKey('shadowing-sample'),
        borderRadius: BorderRadius.circular(22),
        onTap: busy && !playing ? null : _controller.listenSample,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.volume_up_outlined,
                size: 18,
                color: playing ? _linkBlue : const Color(0xFF8F9BFF),
              ),
              const SizedBox(width: 8),
              Text(
                playing ? 'Đang phát...' : 'Nghe mẫu',
                style: TextStyle(
                  color: AppPalette.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWaveform() {
    final phase = _controller.phase;
    final active = phase == ShadowingPhase.listening;
    final done = phase == ShadowingPhase.result;
    return SizedBox(
      height: 48,
      width: double.infinity,
      child: CustomPaint(
        painter: _WaveformPainter(
          level: active ? max(0.15, _controller.level) : (done ? 1.0 : 0.0),
          color: active || done
              ? _linkBlue
              : AppPalette.textPrimary.withValues(alpha: 0.12),
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    final c = _controller;
    switch (c.phase) {
      case ShadowingPhase.result:
        return _buildResultControls(c.result!);
      case ShadowingPhase.listening:
        return Column(
          children: [
            _MicButton(listening: true, onTap: c.stopListening),
            const SizedBox(height: 12),
            Text(
              c.partialText.isEmpty ? 'Đang nghe bạn nói...' : c.partialText,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _linkBlue,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      case ShadowingPhase.scoring:
        return SizedBox(
          height: 112,
          child: Center(
            child: CircularProgressIndicator(color: AppPalette.accent),
          ),
        );
      case ShadowingPhase.error:
        return Column(
          children: [
            Text(
              c.error ?? 'Có lỗi xảy ra.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _wrongRed,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            _MicButton(listening: false, onTap: c.startListening),
            const SizedBox(height: 12),
            Text(
              'Chạm để thử lại',
              style: TextStyle(color: AppPalette.textSecondary, fontSize: 13),
            ),
          ],
        );
      case ShadowingPhase.ready:
      case ShadowingPhase.playingSample:
      case ShadowingPhase.summary:
        return Column(
          children: [
            _MicButton(
              listening: false,
              onTap: c.phase == ShadowingPhase.ready ? c.startListening : null,
            ),
            const SizedBox(height: 12),
            Text(
              'Chạm để bắt đầu nói',
              style: TextStyle(color: AppPalette.textSecondary, fontSize: 13),
            ),
          ],
        );
    }
  }

  Widget _buildResultControls(ShadowingLineScore result) {
    final c = _controller;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '${result.score}%',
              style: const TextStyle(
                color: _linkBlue,
                fontSize: 38,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'giống bản gốc',
              style: TextStyle(color: AppPalette.textSecondary, fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _PillButton(
                key: const ValueKey('shadowing-retry'),
                label: 'Thử lại',
                color: AppPalette.background,
                onTap: c.retry,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _PillButton(
                key: const ValueKey('shadowing-next'),
                label: c.isLast ? 'Xem kết quả' : 'Câu tiếp theo',
                color: AppPalette.accent,
                onTap: c.next,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ------------------------------------------------------------ tổng kết

  Widget _buildSummary() {
    final c = _controller;
    final weak = c.weakLines;
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Text(
                  '${c.sessionAverage}%',
                  style: const TextStyle(
                    color: _linkBlue,
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'điểm trung bình · ${c.practicedCount} câu',
                  style: TextStyle(color: AppPalette.textSecondary),
                ),
                const SizedBox(height: 24),
                if (weak.isNotEmpty) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Câu cần luyện thêm',
                      style: TextStyle(
                        color: AppPalette.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView(
                      children: [
                        for (final index in weak)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              widget.cues[index].text,
                              style: TextStyle(
                                color: AppPalette.textPrimary,
                                fontSize: 15,
                              ),
                            ),
                            trailing: Text(
                              '${c.bestScores[index] ?? 0}',
                              style: const TextStyle(
                                color: _wrongRed,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ] else
                  Expanded(
                    child: Center(
                      child: Text(
                        'Tuyệt vời! Mọi câu đều đạt.',
                        style: TextStyle(color: AppPalette.textSecondary),
                      ),
                    ),
                  ),
                Row(
                  children: [
                    if (weak.isNotEmpty) ...[
                      Expanded(
                        child: _PillButton(
                          label: 'Luyện lại câu yếu',
                          color: AppPalette.surface,
                          onTap: c.practiceWeakLines,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: _PillButton(
                        label: 'Xong',
                        color: AppPalette.accent,
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MicButton extends StatelessWidget {
  final bool listening;
  final VoidCallback? onTap;

  const _MicButton({required this.listening, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey(listening ? 'shadowing-stop' : 'shadowing-mic'),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: listening ? 76 : 60,
        height: listening ? 76 : 60,
        padding: EdgeInsets.all(listening ? 8 : 0),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: listening
              ? AppPalette.accent.withValues(alpha: 0.22)
              : Colors.transparent,
        ),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: onTap == null
                ? AppPalette.accent.withValues(alpha: 0.4)
                : AppPalette.accent,
          ),
          child: Icon(
            listening ? Icons.stop_rounded : Icons.mic_rounded,
            color: AppPalette.textPrimary,
            size: 26,
          ),
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _PillButton({
    super.key,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 48,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: AppPalette.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dải sóng âm: các thanh có chiều cao cố định theo mẫu, nhân với mức âm lượng hiện tại.
class _WaveformPainter extends CustomPainter {
  final double level;
  final Color color;

  const _WaveformPainter({required this.level, required this.color});

  static const int _bars = 40;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3;
    final gap = size.width / _bars;
    final scale = level.clamp(0.0, 1.0);
    for (var i = 0; i < _bars; i++) {
      final shape =
          0.25 + 0.75 * ((sin(i * 0.9) + sin(i * 0.37 + 1.3)).abs() / 2);
      final h = max(4.0, size.height * shape * (0.2 + 0.8 * scale));
      final x = gap * i + gap / 2;
      canvas.drawLine(
        Offset(x, size.height / 2 - h / 2),
        Offset(x, size.height / 2 + h / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.level != level || old.color != color;
}
