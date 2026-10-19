import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/services/tts_service.dart';
import '../../../../core/theme/adaptive_video_theme.dart';
import '../../../flashcard/data/services/flashcard_service.dart';
import '../../../flashcard/data/services/flashcard_store.dart';
import '../../data/services/dictionary_service.dart';
import '../../domain/models/ruby_segment.dart';

const _subtitleTextStyle = TextStyle(
  fontSize: 16.0,
  fontWeight: FontWeight.bold,
  color: Colors.white,
  height: 1.35,
  shadows: [
    Shadow(color: Colors.black, blurRadius: 5.0),
    Shadow(color: Colors.black87, blurRadius: 1.0),
  ],
);

const _accent = Color(0xFFFE2C55);

/// Phụ đề video. Khi có [sentence] (câu phụ đề thật), câu được tách thành
/// từng từ: rê chuột (hoặc chạm) vào từ để xem cách đọc, nghĩa và lưu vào
/// Flashcard.
class RubySubtitleWidget extends StatefulWidget {
  final List<RubySegment> rubySegments;
  final String translation;
  final AdaptiveVideoTheme? theme;

  /// Câu tiếng Nhật đang hiển thị, dùng để tách từ và tra từ.
  final String? sentence;

  /// Báo cho trình phát biết đang tra từ (để tạm dừng video).
  final ValueChanged<bool>? onLookupActiveChanged;

  const RubySubtitleWidget({
    super.key,
    required this.rubySegments,
    required this.translation,
    this.theme,
    this.sentence,
    this.onLookupActiveChanged,
  });

  @override
  State<RubySubtitleWidget> createState() => _RubySubtitleWidgetState();
}

class _RubySubtitleWidgetState extends State<RubySubtitleWidget> {
  Future<List<SubtitleToken>>? _tokensFuture;
  SubtitleToken? _selected;
  int? _selectedIndex;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _loadTokens();
  }

  @override
  void didUpdateWidget(covariant RubySubtitleWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sentence != widget.sentence) {
      _clearSelection();
      _loadTokens();
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    if (_selected != null) widget.onLookupActiveChanged?.call(false);
    super.dispose();
  }

  void _loadTokens() {
    final sentence = widget.sentence?.trim() ?? '';
    _tokensFuture = sentence.isEmpty
        ? null
        : DictionaryService.instance.tokenize(sentence);
  }

  void _select(SubtitleToken token, int index) {
    _hideTimer?.cancel();
    if (_selectedIndex == index) return;
    final wasActive = _selected != null;
    setState(() {
      _selected = token;
      _selectedIndex = index;
    });
    if (!wasActive) widget.onLookupActiveChanged?.call(true);
  }

  void _toggle(SubtitleToken token, int index) {
    if (_selectedIndex == index) {
      _clearSelection();
    } else {
      _select(token, index);
    }
  }

  void _clearSelection() {
    _hideTimer?.cancel();
    if (_selected == null) return;
    setState(() {
      _selected = null;
      _selectedIndex = null;
    });
    widget.onLookupActiveChanged?.call(false);
  }

  /// Trễ một chút để người dùng kịp di chuột từ chữ lên bảng tra từ.
  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted) _clearSelection();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme ?? const AdaptiveVideoTheme(isLight: false);
    final selected = _selected;

    return MouseRegion(
      onEnter: (_) => _hideTimer?.cancel(),
      onExit: (_) => _scheduleHide(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selected != null) ...[
            // Chặn chạm vào vùng trống của bảng để không bật/tắt video.
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: _WordLookupCard(
                key: ValueKey(selected.baseForm),
                token: selected,
                sentence: widget.sentence ?? '',
              ),
            ),
            const SizedBox(height: 8.0),
          ],
          _tokensFuture == null
              ? Wrap(
                  alignment: WrapAlignment.start,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  spacing: 6.0,
                  runSpacing: 4.0,
                  children: widget.rubySegments
                      .map((segment) => _buildRubySegment(segment, theme))
                      .toList(),
                )
              : _buildTokenizedSentence(),
          const SizedBox(height: 6.0),
          Text(
            widget.translation,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              height: 1.25,
              shadows: [
                Shadow(color: Colors.black, blurRadius: 4.0),
                Shadow(color: Colors.black87, blurRadius: 1.0),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTokenizedSentence() {
    return FutureBuilder<List<SubtitleToken>>(
      future: _tokensFuture,
      builder: (context, snapshot) {
        final tokens = snapshot.data;
        // Đang tải hoặc lỗi: hiển thị câu nguyên văn như cũ.
        if (tokens == null || tokens.isEmpty) {
          return Text(widget.sentence ?? '', style: _subtitleTextStyle);
        }

        return Wrap(
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            for (var i = 0; i < tokens.length; i++)
              tokens[i].lookupable
                  ? _buildWord(tokens[i], i)
                  : Text(tokens[i].surface, style: _subtitleTextStyle),
          ],
        );
      },
    );
  }

  Widget _buildWord(SubtitleToken token, int index) {
    final isSelected = _selectedIndex == index;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _select(token, index),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _toggle(token, index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 1.0),
          decoration: BoxDecoration(
            color: isSelected
                ? _accent.withValues(alpha: 0.35)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4.0),
          ),
          child: Text(token.surface, style: _subtitleTextStyle),
        ),
      ),
    );
  }

  Widget _buildRubySegment(RubySegment segment, AdaptiveVideoTheme theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Ruby pronunciation (Furigana)
        if (segment.furigana.isNotEmpty) ...[
          Text(
            segment.furigana,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: theme.furiganaColor,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 1.0),
        ],
        // Kanji / Kana Text
        Text(
          segment.kanji,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: _subtitleTextStyle.copyWith(height: 1.2),
        ),
      ],
    );
  }
}

/// Bảng tra từ: từ gốc, cách đọc, nghĩa, cấp JLPT, phát âm và lưu Flashcard.
class _WordLookupCard extends StatefulWidget {
  final SubtitleToken token;
  final String sentence;

  const _WordLookupCard({
    super.key,
    required this.token,
    required this.sentence,
  });

  @override
  State<_WordLookupCard> createState() => _WordLookupCardState();
}

class _WordLookupCardState extends State<_WordLookupCard> {
  /// Những từ đã lưu trong phiên này, để không lưu trùng.
  static final Set<String> _savedTerms = {};

  late Future<WordLookup> _lookupFuture;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _lookupFuture = DictionaryService.instance.lookup(widget.token.baseForm);
  }

  void _retry() {
    setState(() {
      _lookupFuture = DictionaryService.instance.lookup(widget.token.baseForm);
    });
  }

  Future<void> _save(WordLookup word) async {
    if (_isSaving || _savedTerms.contains(word.term)) return;
    setState(() => _isSaving = true);
    try {
      await FlashcardService.instance.saveVideoVocab(
        term: word.term,
        reading: word.reading,
        meaning: word.meaning,
        example: widget.sentence.isNotEmpty ? widget.sentence : null,
      );
      _savedTerms.add(word.term);
      // Để Thư viện thẻ nạp lại bộ "Từ vựng đã lưu từ Video".
      FlashcardStore.instance.invalidateAll();
      if (!mounted) return;
      _showSnackBar('Đã lưu "${word.term}" vào Flashcard');
    } on ApiException catch (e) {
      if (mounted) _showSnackBar(e.message);
    } catch (_) {
      if (mounted) _showSnackBar('Không lưu được từ. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 320.0),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xF21E1E1E),
        borderRadius: BorderRadius.circular(14.0),
        border: Border.all(color: Colors.white12),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: FutureBuilder<WordLookup>(
        future: _lookupFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return _buildLoading();
          }
          final word = snapshot.data;
          if (snapshot.hasError || word == null || !word.found) {
            return _buildNotFound();
          }
          return _buildContent(word);
        },
      ),
    );
  }

  Widget _buildHeader({required String term, required String reading}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: term,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                if (reading.isNotEmpty && reading != term)
                  TextSpan(
                    text: '  [$reading]',
                    style: const TextStyle(fontSize: 14, color: Colors.white60),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        InkResponse(
          onTap: () => TtsService.speak(text: term),
          radius: 20,
          child: Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: Colors.white12,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.volume_up_rounded,
              size: 18,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoading() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(
          term: widget.token.baseForm,
          reading: widget.token.reading,
        ),
        const SizedBox(height: 12),
        const Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: _accent),
            ),
            SizedBox(width: 8),
            Text(
              'Đang tra từ...',
              style: TextStyle(color: Colors.white60, fontSize: 13),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNotFound() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(
          term: widget.token.baseForm,
          reading: widget.token.reading,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Không tìm thấy nghĩa của từ này.',
                style: TextStyle(color: Colors.white60, fontSize: 13),
              ),
            ),
            TextButton(
              onPressed: _retry,
              child: const Text('Thử lại', style: TextStyle(color: _accent)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildContent(WordLookup word) {
    final isSaved = _savedTerms.contains(word.term);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(term: word.term, reading: word.reading),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                word.meaning,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ),
            if (word.jlptLevel.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _accent.withValues(alpha: 0.6)),
                ),
                child: Text(
                  word.jlptLevel,
                  style: const TextStyle(
                    color: _accent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 40,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: isSaved ? Colors.white12 : _accent,
              disabledBackgroundColor: isSaved
                  ? Colors.white12
                  : _accent.withValues(alpha: 0.6),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            onPressed: isSaved || _isSaving ? null : () => _save(word),
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    isSaved ? Icons.check_rounded : Icons.add_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
            label: Text(
              isSaved ? 'Đã lưu vào Flashcard' : 'Lưu vào Flashcard',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
