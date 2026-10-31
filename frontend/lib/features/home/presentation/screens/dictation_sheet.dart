import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/services/tts_service.dart';
import '../../../../core/theme/app_palette.dart';
import '../../domain/models/ruby_segment.dart';

Future<void> showDictationSheet(
  BuildContext context, {
  required List<SubtitleCue> cues,
  int startIndex = 0,
  VideoPlayerController? videoController,
  void Function(int lineIndex, int score)? onScore,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _DictationSheet(
      cues: cues,
      startIndex: startIndex,
      videoController: videoController,
      onScore: onScore,
    ),
  );
}

class _DictationSheet extends StatefulWidget {
  final List<SubtitleCue> cues;
  final int startIndex;
  final VideoPlayerController? videoController;
  final void Function(int lineIndex, int score)? onScore;

  const _DictationSheet({
    required this.cues,
    required this.startIndex,
    this.videoController,
    this.onScore,
  });

  @override
  State<_DictationSheet> createState() => _DictationSheetState();
}

class _DictationSheetState extends State<_DictationSheet> {
  static const _blue = Color(0xFF38BDF8);
  static const _wrong = Color(0xFFFF6B6B);

  final TextEditingController _answerController = TextEditingController();
  late int _index = widget.startIndex
      .clamp(0, widget.cues.length - 1)
      .toInt();
  bool _playing = false;
  int? _score;

  SubtitleCue get _cue => widget.cues[_index];
  bool get _showResult => _score != null;

  @override
  void dispose() {
    _answerController.dispose();
    TtsService.stop();
    widget.videoController?.pause();
    super.dispose();
  }

  Future<void> _play() async {
    if (_playing) return;
    setState(() => _playing = true);
    final video = widget.videoController;
    try {
      if (video != null && video.value.isInitialized) {
        const pad = Duration(milliseconds: 200);
        final start = _cue.start > pad ? _cue.start - pad : Duration.zero;
        final end = _cue.end + pad;
        final done = Completer<void>();
        void listener() {
          if (video.value.position >= end && !done.isCompleted) {
            done.complete();
          }
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
      } else {
        final done = Completer<void>();
        TtsService.speak(
          text: _cue.text,
          lang: 'ja-JP',
          rate: 0.9,
          onComplete: () {
            if (!done.isCompleted) done.complete();
          },
        );
        await done.future.timeout(const Duration(seconds: 12), onTimeout: () {});
      }
    } finally {
      if (mounted) setState(() => _playing = false);
    }
  }

  String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[\s、。！？!?.,・「」『』（）()\-]'), '');

  int _levenshtein(String a, String b) {
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    var previous = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      final current = List<int>.filled(b.length + 1, 0)..[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        current[j] = min(
          min(current[j - 1] + 1, previous[j] + 1),
          previous[j - 1] + cost,
        );
      }
      previous = current;
    }
    return previous.last;
  }

  /// Tô riêng phần ký tự không khớp thay vì biến cả câu thành màu đỏ.
  Widget _diffText(String text, String comparison, {double fontSize = 18}) {
    final sourceChars = text.split('');
    final meaningful = <String>[];
    final sourceIndexes = <int>[];
    for (var i = 0; i < sourceChars.length; i++) {
      final normalized = _normalize(sourceChars[i]);
      if (normalized.isNotEmpty) {
        meaningful.add(normalized);
        sourceIndexes.add(i);
      }
    }
    final target = _normalize(comparison).split('');
    final rows = meaningful.length + 1;
    final cols = target.length + 1;
    final lcs = List.generate(rows, (_) => List<int>.filled(cols, 0));
    for (var i = 1; i < rows; i++) {
      for (var j = 1; j < cols; j++) {
        lcs[i][j] = meaningful[i - 1] == target[j - 1]
            ? lcs[i - 1][j - 1] + 1
            : max(lcs[i - 1][j], lcs[i][j - 1]);
      }
    }
    final matched = <int>{};
    var i = meaningful.length;
    var j = target.length;
    while (i > 0 && j > 0) {
      if (meaningful[i - 1] == target[j - 1]) {
        matched.add(sourceIndexes[i - 1]);
        i--;
        j--;
      } else if (lcs[i - 1][j] >= lcs[i][j - 1]) {
        i--;
      } else {
        j--;
      }
    }

    return Text.rich(
      TextSpan(
        children: [
          for (var index = 0; index < sourceChars.length; index++)
            TextSpan(
              text: sourceChars[index],
              style: TextStyle(
                color: _normalize(sourceChars[index]).isEmpty ||
                        matched.contains(index)
                    ? AppPalette.textPrimary
                    : _wrong,
                decoration: _normalize(sourceChars[index]).isEmpty ||
                        matched.contains(index)
                    ? TextDecoration.none
                    : TextDecoration.underline,
                decorationColor: _wrong,
              ),
            ),
        ],
      ),
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w800),
    );
  }

  void _grade() {
    final expected = _normalize(_cue.text);
    final actual = _normalize(_answerController.text);
    if (actual.isEmpty) return;
    final longest = max(expected.length, actual.length);
    final score = longest == 0
        ? 100
        : ((1 - _levenshtein(expected, actual) / longest) * 100)
              .round()
              .clamp(0, 100)
              .toInt();
    FocusScope.of(context).unfocus();
    setState(() => _score = score);
    widget.onScore?.call(_index, score);
  }

  void _retry() {
    setState(() {
      _score = null;
      _answerController.clear();
    });
    _play();
  }

  void _next() {
    if (_index >= widget.cues.length - 1) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _index++;
      _score = null;
      _answerController.clear();
    });
    _play();
  }

  @override
  Widget build(BuildContext context) {
    final height = min(MediaQuery.sizeOf(context).height * 0.68, 580.0);
    return SizedBox(
      height: height,
      child: Material(
        color: AppPalette.navBar,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              _header(),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: _showResult ? _result() : _practice(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() => Column(
    children: [
      const SizedBox(height: 10),
      Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppPalette.textPrimary.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
        child: Row(
          children: [
            Text(
              'Nghe và viết',
              style: TextStyle(
                color: AppPalette.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: Icon(Icons.close_rounded, color: AppPalette.textPrimary),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _audioButton() => Column(
    children: [
      InkWell(
        onTap: _play,
        customBorder: const CircleBorder(),
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppPalette.accent,
            shape: BoxShape.circle,
          ),
          child: _playing
              ? const Padding(
                  padding: EdgeInsets.all(27),
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.volume_up_rounded, color: Colors.white, size: 30),
        ),
      ),
      const SizedBox(height: 14),
      Text('Chạm để nghe câu', style: TextStyle(color: AppPalette.textSecondary)),
    ],
  );

  Widget _practice() => Column(
    children: [
      const SizedBox(height: 70),
      _audioButton(),
      const Spacer(),
      TextField(
        controller: _answerController,
        minLines: 3,
        maxLines: 4,
        onChanged: (_) => setState(() {}),
        style: TextStyle(color: AppPalette.textPrimary, fontSize: 16),
        decoration: InputDecoration(
          hintText: 'Gõ lại câu bạn vừa nghe...',
          hintStyle: TextStyle(color: AppPalette.textSecondary),
          filled: true,
          fillColor: AppPalette.background,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      const SizedBox(height: 14),
      SizedBox(
        width: double.infinity,
        height: 50,
        child: FilledButton(
          onPressed: _answerController.text.trim().isEmpty ? null : _grade,
          child: const Text('Chấm điểm'),
        ),
      ),
    ],
  );

  Widget _result() => Column(
    children: [
      const SizedBox(height: 50),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '$_score%',
            style: const TextStyle(
              color: _blue,
              fontSize: 38,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 7, left: 8),
            child: Text('chính xác', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
      const SizedBox(height: 24),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppPalette.background,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text('ĐÁP ÁN', style: TextStyle(color: AppPalette.textSecondary, fontSize: 11)),
            const SizedBox(height: 8),
            _diffText(_cue.text, _answerController.text),
            const SizedBox(height: 16),
            Text('BẠN VIẾT', style: TextStyle(color: AppPalette.textSecondary, fontSize: 11)),
            const SizedBox(height: 8),
            _diffText(
              _answerController.text,
              _cue.text,
              fontSize: 16,
            ),
            if (_cue.translation.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                _cue.translation,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppPalette.textSecondary, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
      const Spacer(),
      Row(
        children: [
          Expanded(child: OutlinedButton(onPressed: _retry, child: const Text('Thử lại'))),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: _next,
              child: Text(_index == widget.cues.length - 1 ? 'Hoàn thành' : 'Câu tiếp theo'),
            ),
          ),
        ],
      ),
    ],
  );
}
