import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../data/services/dictionary_service.dart';
import '../../domain/models/ruby_segment.dart';
import 'grammar_lookup_card.dart';
import 'ruby_subtitle_widget.dart';
import 'word_lookup_card.dart';

/// Câu tiếng Nhật chạm vào từng từ vựng (gạch chân xanh) để tra nghĩa/lưu Flashcard
/// hoặc chạm vào mẫu ngữ pháp (gạch chân cam) để xem bảng giải thích ngữ pháp.
class LookupSentenceText extends StatefulWidget {
  final String sentence;
  final TextStyle style;
  final List<GrammarPointInfo> grammarPoints;

  /// Báo cho nơi dùng biết đang tra từ / ngữ pháp (để tạm dừng video).
  final ValueChanged<bool>? onLookupActiveChanged;

  const LookupSentenceText({
    super.key,
    required this.sentence,
    required this.style,
    this.grammarPoints = const [],
    this.onLookupActiveChanged,
  });

  @override
  State<LookupSentenceText> createState() => _LookupSentenceTextState();
}

class _LookupSentenceTextState extends State<LookupSentenceText> {
  static const double _cardWidth = 288.0;
  static const double _maxCardHeight = 280.0;
  static const double _edge = 8.0;
  static const double _gap = 18.0;

  /// Câu đang mở bảng tra từ/ngữ pháp.
  static _LookupSentenceTextState? _current;

  List<SubtitleToken> _tokens = const [];
  List<InteractiveSentenceSegment> _segments = const [];
  List<TapGestureRecognizer?> _recognizers = const [];
  int? _selectedIndex;
  OverlayEntry? _overlay;

  @override
  void initState() {
    super.initState();
    RubySubtitleWidget.dismissSignal.addListener(_clearSelection);
    _rebuildSegments();
    _loadTokens();
  }

  @override
  void didUpdateWidget(covariant LookupSentenceText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sentence != widget.sentence ||
        oldWidget.grammarPoints != widget.grammarPoints) {
      _clearSelection();
      _disposeRecognizers();
      if (oldWidget.sentence != widget.sentence) {
        _tokens = const [];
        _rebuildSegments();
        _loadTokens();
      } else {
        _rebuildSegments();
      }
    }
  }

  @override
  void dispose() {
    RubySubtitleWidget.dismissSignal.removeListener(_clearSelection);
    if (_current == this) _current = null;
    _removeOverlay();
    if (_selectedIndex != null) widget.onLookupActiveChanged?.call(false);
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r?.dispose();
    }
    _recognizers = const [];
  }

  void _rebuildSegments() {
    _disposeRecognizers();
    final segs = buildInteractiveSegments(
      sentence: widget.sentence,
      tokens: _tokens,
      grammarPoints: widget.grammarPoints,
    );
    _segments = segs;
    _recognizers = [
      for (var i = 0; i < segs.length; i++)
        segs[i].isInteractive
            ? (TapGestureRecognizer()
                ..onTapUp = (details) => _toggle(i, details.globalPosition))
            : null,
    ];
  }

  Future<void> _loadTokens() async {
    final sentence = widget.sentence.trim();
    if (sentence.isEmpty) return;
    try {
      final tokens = await DictionaryService.instance.tokenize(sentence);
      if (!mounted || sentence != widget.sentence.trim()) return;
      setState(() {
        _tokens = tokens;
        _rebuildSegments();
      });
    } catch (_) {
      // Không tách được từ thì vẫn hiển thị ngữ pháp (nếu có) và câu nguyên văn.
    }
  }

  void _toggle(int index, Offset anchor) {
    if (_selectedIndex == index) {
      _clearSelection();
      return;
    }
    final previous = _current;
    if (previous != null && previous != this) previous._clearSelection();
    _current = this;
    final wasActive = _selectedIndex != null;
    _removeOverlay();
    setState(() => _selectedIndex = index);
    if (!wasActive) widget.onLookupActiveChanged?.call(true);
    _showOverlay(_segments[index], anchor);
  }

  void _clearSelection() {
    if (_selectedIndex == null) return;
    if (_current == this) _current = null;
    _removeOverlay();
    setState(() => _selectedIndex = null);
    widget.onLookupActiveChanged?.call(false);
  }

  void _showOverlay(InteractiveSentenceSegment segment, Offset anchor) {
    final screen = MediaQuery.sizeOf(context);
    final left = (anchor.dx - _cardWidth / 2).clamp(
      _edge,
      screen.width - _cardWidth - _edge,
    );
    final above = anchor.dy > _maxCardHeight + _gap + _edge + 40;
    final maxHeight = above
        ? (anchor.dy - _gap - _edge).clamp(0.0, _maxCardHeight).toDouble()
        : (screen.height - anchor.dy - _gap - _edge)
              .clamp(0.0, _maxCardHeight)
              .toDouble();

    final Widget card = segment.isGrammar
        ? GrammarLookupCard(
            key: ValueKey('grammar-${segment.grammar!.pattern}-${segment.text}'),
            grammar: segment.grammar!,
            sentence: widget.sentence,
            onClose: _clearSelection,
          )
        : WordLookupCard(
            key: ValueKey('vocab-${segment.token!.baseForm}'),
            token: segment.token!,
            sentence: widget.sentence,
            onClose: _clearSelection,
          );

    _overlay = OverlayEntry(
      builder: (context) => Positioned(
        left: left,
        top: above ? null : anchor.dy + _gap,
        bottom: above ? screen.height - anchor.dy + _gap : null,
        width: _cardWidth,
        child: Material(
          color: Colors.transparent,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: SingleChildScrollView(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {},
                child: card,
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(_overlay!);
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  @override
  Widget build(BuildContext context) {
    if (_segments.isEmpty) {
      return Text(widget.sentence, style: widget.style);
    }
    return Text.rich(
      TextSpan(
        style: widget.style,
        children: [
          for (var i = 0; i < _segments.length; i++)
            _buildSpan(_segments[i], i),
        ],
      ),
    );
  }

  TextSpan _buildSpan(InteractiveSentenceSegment seg, int index) {
    if (!seg.isInteractive) {
      return TextSpan(text: seg.text);
    }
    final underlineColor = seg.isGrammar
        ? kGrammarUnderlineColor
        : kVocabUnderlineColor;
    final isSelected = _selectedIndex == index;
    return TextSpan(
      text: seg.text,
      recognizer: _recognizers[index],
      style: TextStyle(
        decoration: TextDecoration.underline,
        decorationColor: underlineColor,
        decorationThickness: 2.2,
        backgroundColor: isSelected
            ? underlineColor.withValues(alpha: 0.28)
            : null,
      ),
    );
  }
}
