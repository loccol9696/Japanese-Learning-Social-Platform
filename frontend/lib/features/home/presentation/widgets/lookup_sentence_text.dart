import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../data/services/dictionary_service.dart';
import 'ruby_subtitle_widget.dart';
import 'word_lookup_card.dart';

/// Câu tiếng Nhật chạm vào từng từ để tra nghĩa và lưu Flashcard, dùng cho danh sách câu thoại ở màn Kịch bản.
///
/// Giữ nguyên cách trình bày của một [Text] thường (chữ chưa tách xong vẫn hiện nguyên câu), nên chiều cao dòng
/// không đổi khi việc tách từ hoàn tất. Bảng tra từ là [WordLookupCard] dùng chung với phụ đề ở trang chủ.
class LookupSentenceText extends StatefulWidget {
  final String sentence;
  final TextStyle style;

  /// Báo cho nơi dùng biết đang tra từ (để tạm dừng video).
  final ValueChanged<bool>? onLookupActiveChanged;

  const LookupSentenceText({
    super.key,
    required this.sentence,
    required this.style,
    this.onLookupActiveChanged,
  });

  @override
  State<LookupSentenceText> createState() => _LookupSentenceTextState();
}

class _LookupSentenceTextState extends State<LookupSentenceText> {
  static const double _cardWidth = 280.0;
  static const double _maxCardHeight = 260.0;
  static const double _edge = 8.0;
  static const double _gap = 18.0;

  /// Câu đang mở bảng tra từ. Mỗi câu có state riêng nên phải đóng bảng của câu trước khi mở bảng mới,
  /// để trên màn hình luôn chỉ có một bảng.
  static _LookupSentenceTextState? _current;

  List<SubtitleToken> _tokens = const [];
  List<TapGestureRecognizer?> _recognizers = const [];
  int? _selectedIndex;
  OverlayEntry? _overlay;

  @override
  void initState() {
    super.initState();
    RubySubtitleWidget.dismissSignal.addListener(_clearSelection);
    _loadTokens();
  }

  @override
  void didUpdateWidget(covariant LookupSentenceText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sentence != widget.sentence) {
      _clearSelection();
      _disposeRecognizers();
      _tokens = const [];
      _loadTokens();
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

  Future<void> _loadTokens() async {
    final sentence = widget.sentence.trim();
    if (sentence.isEmpty) return;
    try {
      final tokens = await DictionaryService.instance.tokenize(sentence);
      if (!mounted || sentence != widget.sentence.trim()) return;
      _disposeRecognizers();
      setState(() {
        _tokens = tokens;
        _recognizers = [
          for (var i = 0; i < tokens.length; i++)
            tokens[i].lookupable
                ? (TapGestureRecognizer()
                    ..onTapUp = (details) => _toggle(i, details.globalPosition))
                : null,
        ];
      });
    } catch (_) {
      // Không tách được thì vẫn hiện nguyên câu, chỉ là chưa tra từ được.
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
    _showOverlay(_tokens[index], anchor);
  }

  void _clearSelection() {
    if (_selectedIndex == null) return;
    if (_current == this) _current = null;
    _removeOverlay();
    setState(() => _selectedIndex = null);
    widget.onLookupActiveChanged?.call(false);
  }

  void _showOverlay(SubtitleToken token, Offset anchor) {
    final screen = MediaQuery.sizeOf(context);
    final left = (anchor.dx - _cardWidth / 2).clamp(
      _edge,
      screen.width - _cardWidth - _edge,
    );
    // Đủ chỗ phía trên từ được chạm thì đặt bảng ở trên, không thì xuống dưới.
    final above = anchor.dy > _maxCardHeight + _gap + _edge + 40;
    final maxHeight = above
        ? (anchor.dy - _gap - _edge).clamp(0.0, _maxCardHeight).toDouble()
        : (screen.height - anchor.dy - _gap - _edge)
              .clamp(0.0, _maxCardHeight)
              .toDouble();

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
                child: WordLookupCard(
                  key: ValueKey(token.baseForm),
                  token: token,
                  sentence: widget.sentence,
                  onClose: _clearSelection,
                ),
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
    if (_tokens.isEmpty) {
      return Text(widget.sentence, style: widget.style);
    }
    return Text.rich(
      TextSpan(
        style: widget.style,
        children: [
          for (var i = 0; i < _tokens.length; i++)
            TextSpan(
              text: _tokens[i].surface,
              recognizer: _recognizers[i],
              style: _selectedIndex == i
                  ? TextStyle(
                      backgroundColor: AppPalette.accent.withValues(
                        alpha: 0.35,
                      ),
                    )
                  : null,
            ),
        ],
      ),
    );
  }
}
