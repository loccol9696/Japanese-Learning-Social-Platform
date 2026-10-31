import 'package:flutter/material.dart';

import '../../../../core/theme/adaptive_video_theme.dart';
import '../../data/services/dictionary_service.dart';
import '../../domain/models/ruby_segment.dart';
import '../../../../core/theme/app_palette.dart';
import 'word_lookup_card.dart';

TextStyle get _subtitleTextStyle => TextStyle(
  fontFamilyFallback: const ['NotoSansJP'],
  fontSize: 15.5,
  fontWeight: FontWeight.bold,
  color: AppPalette.onVideo,
  height: 1.45,
  letterSpacing: 0.2,
  shadows: [
    Shadow(color: AppPalette.shadow, offset: const Offset(0, 1), blurRadius: 4.0),
  ],
);

Color get _accent => AppPalette.accent;

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

  /// Phát tín hiệu để mọi bảng tra từ đang mở tự đóng (vd. khi rời tab Home).
  static final ValueNotifier<int> _dismissSignal = ValueNotifier<int>(0);
  static void dismissLookups() => _dismissSignal.value++;

  @override
  State<RubySubtitleWidget> createState() => _RubySubtitleWidgetState();
}

class _RubySubtitleWidgetState extends State<RubySubtitleWidget> {
  Future<List<SubtitleToken>>? _tokensFuture;
  SubtitleToken? _selected;
  int? _selectedIndex;
  final GlobalKey _selectedWordKey = GlobalKey();
  OverlayEntry? _lookupOverlay;

  @override
  void initState() {
    super.initState();
    RubySubtitleWidget._dismissSignal.addListener(_clearSelection);
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
    RubySubtitleWidget._dismissSignal.removeListener(_clearSelection);
    _removeLookupOverlay();
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
    if (_selectedIndex == index) return;
    final wasActive = _selected != null;
    _removeLookupOverlay();
    setState(() {
      _selected = token;
      _selectedIndex = index;
    });
    if (!wasActive) widget.onLookupActiveChanged?.call(true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _selected != null) _showLookupOverlay();
    });
  }

  void _toggle(SubtitleToken token, int index) {
    if (_selectedIndex == index) {
      _clearSelection();
    } else {
      _select(token, index);
    }
  }

  void _clearSelection() {
    if (_selected == null) return;
    _removeLookupOverlay();
    setState(() {
      _selected = null;
      _selectedIndex = null;
    });
    widget.onLookupActiveChanged?.call(false);
  }

  void _showLookupOverlay() {
    _removeLookupOverlay();
    final selected = _selected;
    if (selected == null) return;

    final renderObject = _selectedWordKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;
    final targetOffset = renderObject.localToGlobal(Offset.zero);
    final targetSize = renderObject.size;
    final screenSize = MediaQuery.sizeOf(context);
    const cardWidth = 280.0;
    const maxCardHeight = 260.0;
    const edgePadding = 8.0;
    const subtitleGap = 14.0;
    final left = (targetOffset.dx + (targetSize.width - cardWidth) / 2).clamp(
      edgePadding,
      screenSize.width - cardWidth - edgePadding,
    );
    final availableHeight = targetOffset.dy - subtitleGap - edgePadding;
    final cardMaxHeight = availableHeight.clamp(0.0, maxCardHeight).toDouble();
    final bottom = screenSize.height - targetOffset.dy + subtitleGap;

    final overlay = Overlay.of(context, rootOverlay: true);
    _lookupOverlay = OverlayEntry(
      builder: (context) {
        return Positioned(
          left: left,
          bottom: bottom,
          width: cardWidth,
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
                    child: WordLookupCard(
                      key: ValueKey(selected.baseForm),
                      token: selected,
                      sentence: widget.sentence ?? '',
                      onClose: _clearSelection,
                    ),
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
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Giữ nguyên kích thước subtitle zone; bảng tra từ không được tham
        // gia vào layout để không đẩy video, progress bar hoặc navigation.
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.35,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
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
              if (widget.translation.trim().isNotEmpty) ...[
                const SizedBox(height: 8.0),
                Text(
                  widget.translation,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.0,
                    fontWeight: FontWeight.w500,
                    color: AppPalette.onVideo.withValues(alpha: 0.85),
                    height: 1.4,
                    letterSpacing: 0.1,
                    shadows: [
                      Shadow(
                        color: AppPalette.videoScrim.withValues(alpha: 0.50),
                        offset: Offset(0, 1),
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
          spacing: 1.0,
          runSpacing: 4.0,
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
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _toggle(token, index),
        child: Container(
          key: isSelected ? _selectedWordKey : null,
          padding: const EdgeInsets.symmetric(horizontal: 1.5, vertical: 1.0),
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
              height: 1.2,
              shadows: [
                Shadow(
                  color: AppPalette.videoScrim.withValues(alpha: 0.50),
                  offset: Offset(0, 1),
                  blurRadius: 3.0,
                ),
              ],
            ),
          ),
          const SizedBox(height: 2.0),
        ],
        // Kanji / Kana Text
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
