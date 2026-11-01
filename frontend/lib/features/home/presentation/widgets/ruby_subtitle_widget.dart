import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/adaptive_video_theme.dart';
import '../../../../core/theme/app_palette.dart';
import '../../data/services/dictionary_service.dart';
import '../../domain/models/ruby_segment.dart';
import 'grammar_lookup_card.dart';
import 'word_lookup_card.dart';

TextStyle get _subtitleTextStyle => TextStyle(
  fontFamilyFallback: const ['NotoSansJP'],
  fontSize: 18.0,
  fontWeight: FontWeight.w800,
  color: AppPalette.onVideo,
  height: 1.48,
  letterSpacing: 0.2,
  shadows: [
    Shadow(
      color: AppPalette.shadow,
      offset: const Offset(0, 1),
      blurRadius: 4.0,
    ),
  ],
);

/// Phụ đề video ở Trang chủ:
/// - Từ vựng tra được gạch chân màu xanh dương ([kVocabUnderlineColor]) -> chạm mở [WordLookupCard].
/// - Mẫu ngữ pháp gạch chân màu cam ([kGrammarUnderlineColor]) -> chạm mở [GrammarLookupCard].
class RubySubtitleWidget extends StatefulWidget {
  final List<RubySegment> rubySegments;
  final String translation;
  final AdaptiveVideoTheme? theme;

  /// Câu tiếng Nhật đang hiển thị, dùng để tách từ và tra từ/ngữ pháp.
  final String? sentence;

  /// Các mẫu ngữ pháp của câu phụ đề hiện tại.
  final List<GrammarPointInfo> grammarPoints;

  /// Báo cho trình phát biết đang tra từ / ngữ pháp (để tạm dừng video).
  final ValueChanged<bool>? onLookupActiveChanged;

  const RubySubtitleWidget({
    super.key,
    required this.rubySegments,
    required this.translation,
    this.theme,
    this.sentence,
    this.grammarPoints = const [],
    this.onLookupActiveChanged,
  });

  /// Phát tín hiệu để mọi bảng tra từ/ngữ pháp đang mở tự đóng (vd. khi rời tab Home).
  static final ValueNotifier<int> _dismissSignal = ValueNotifier<int>(0);
  static void dismissLookups() => _dismissSignal.value++;

  /// Để các nơi khác cũng dùng bảng tra từ (vd. màn Kịch bản) tự đóng theo cùng tín hiệu.
  static ValueListenable<int> get dismissSignal => _dismissSignal;

  @override
  State<RubySubtitleWidget> createState() => _RubySubtitleWidgetState();
}

class _RubySubtitleWidgetState extends State<RubySubtitleWidget> {
  static const double _cardWidth = 288.0;
  static const double _maxCardHeight = 280.0;
  static const double _edgePadding = 8.0;
  static const double _subtitleGap = 18.0;

  List<SubtitleToken> _tokens = const [];
  List<InteractiveSentenceSegment> _segments = const [];
  List<TapGestureRecognizer?> _recognizers = const [];
  int? _selectedIndex;
  OverlayEntry? _lookupOverlay;

  String get _effectiveSentence {
    final s = widget.sentence?.trim() ?? '';
    if (s.isNotEmpty) return s;
    return widget.rubySegments.map((e) => e.kanji).join().trim();
  }

  @override
  void initState() {
    super.initState();
    RubySubtitleWidget._dismissSignal.addListener(_clearSelection);
    _rebuildSegments();
    _loadTokens();
  }

  @override
  void didUpdateWidget(covariant RubySubtitleWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldSentence = (oldWidget.sentence?.trim().isNotEmpty == true)
        ? oldWidget.sentence!.trim()
        : oldWidget.rubySegments.map((e) => e.kanji).join().trim();
    final newSentence = _effectiveSentence;
    if (oldSentence != newSentence ||
        oldWidget.grammarPoints != widget.grammarPoints) {
      _clearSelection();
      _disposeRecognizers();
      if (oldSentence != newSentence) {
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
    RubySubtitleWidget._dismissSignal.removeListener(_clearSelection);
    _removeLookupOverlay();
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
    final sentence = _effectiveSentence;
    if (sentence.isEmpty) {
      _segments = const [];
      return;
    }
    final segs = buildInteractiveSegments(
      sentence: sentence,
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
    final sentence = _effectiveSentence;
    if (sentence.isEmpty) return;
    try {
      final tokens = await DictionaryService.instance.tokenize(sentence);
      if (!mounted || sentence != _effectiveSentence) return;
      setState(() {
        _tokens = tokens;
        _rebuildSegments();
      });
    } catch (_) {}
  }

  void _toggle(int index, Offset anchor) {
    if (_selectedIndex == index) {
      _clearSelection();
      return;
    }
    final wasActive = _selectedIndex != null;
    _removeLookupOverlay();
    setState(() => _selectedIndex = index);
    if (!wasActive) widget.onLookupActiveChanged?.call(true);
    _showLookupOverlay(_segments[index], anchor);
  }

  void _clearSelection() {
    if (_selectedIndex == null) return;
    _removeLookupOverlay();
    setState(() => _selectedIndex = null);
    widget.onLookupActiveChanged?.call(false);
  }

  void _showLookupOverlay(InteractiveSentenceSegment segment, Offset anchor) {
    _removeLookupOverlay();
    final screenSize = MediaQuery.sizeOf(context);
    final left = (anchor.dx - _cardWidth / 2).clamp(
      _edgePadding,
      screenSize.width - _cardWidth - _edgePadding,
    );
    final availableHeight = anchor.dy - _subtitleGap - _edgePadding;
    final cardMaxHeight = availableHeight.clamp(0.0, _maxCardHeight).toDouble();
    final bottom = screenSize.height - anchor.dy + _subtitleGap;

    final sentence = _effectiveSentence;
    final Widget card = segment.isGrammar
        ? GrammarLookupCard(
            key: ValueKey('grammar-${segment.grammar!.pattern}-${segment.text}'),
            grammar: segment.grammar!,
            sentence: sentence,
            onClose: _clearSelection,
          )
        : WordLookupCard(
            key: ValueKey('vocab-${segment.token!.baseForm}'),
            token: segment.token!,
            sentence: sentence,
            onClose: _clearSelection,
          );

    final overlay = Overlay.of(context, rootOverlay: true);
    _lookupOverlay = OverlayEntry(
      builder: (context) {
        return Positioned(
          left: left,
          bottom: bottom,
          width: _cardWidth,
          child: Material(
            color: Colors.transparent,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: cardMaxHeight),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.96, end: 1.0),
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOutCubic,
                builder: (context, scale, child) {
                  return Opacity(
                    opacity: ((scale - 0.96) / 0.04).clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: scale,
                      alignment: Alignment.bottomCenter,
                      child: child,
                    ),
                  );
                },
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
      },
    );
    overlay.insert(_lookupOverlay!);
  }

  void _removeLookupOverlay() {
    _lookupOverlay?.remove();
    _lookupOverlay = null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme ?? const AdaptiveVideoTheme(isLight: false);
    final sentence = _effectiveSentence;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.35,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (sentence.isEmpty)
                Wrap(
                  alignment: WrapAlignment.start,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  spacing: 6.0,
                  runSpacing: 4.0,
                  children: widget.rubySegments
                      .map((segment) => _buildRubySegment(segment, theme))
                      .toList(),
                )
              else
                _buildSegmentedSentence(sentence),
              if (widget.translation.trim().isNotEmpty) ...[
                const SizedBox(height: 8.0),
                Text(
                  widget.translation,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: AppPalette.onVideo.withValues(alpha: 0.88),
                    height: 1.4,
                    letterSpacing: 0.1,
                    shadows: [
                      Shadow(
                        color: AppPalette.videoScrim.withValues(alpha: 0.50),
                        offset: const Offset(0, 1),
                        blurRadius: 3.0,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSegmentedSentence(String sentence) {
    if (_segments.isEmpty) {
      return Text(sentence, style: _subtitleTextStyle);
    }
    return Text.rich(
      TextSpan(
        style: _subtitleTextStyle,
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
        decorationThickness: 2.3,
        backgroundColor: isSelected
            ? underlineColor.withValues(alpha: 0.28)
            : null,
      ),
    );
  }

  Widget _buildRubySegment(RubySegment segment, AdaptiveVideoTheme theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (segment.furigana.isNotEmpty) ...[
          Text(
            segment.furigana,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: theme.furiganaColor,
              height: 1.2,
              shadows: [
                Shadow(
                  color: AppPalette.videoScrim.withValues(alpha: 0.50),
                  offset: const Offset(0, 1),
                  blurRadius: 3.0,
                ),
              ],
            ),
          ),
          const SizedBox(height: 2.0),
        ],
        Text(
          segment.kanji,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: _subtitleTextStyle,
        ),
      ],
    );
  }
}
