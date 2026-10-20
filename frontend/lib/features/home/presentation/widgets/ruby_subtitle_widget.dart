import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/services/tts_service.dart';
import '../../../../core/theme/adaptive_video_theme.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../flashcard/data/services/flashcard_service.dart';
import '../../../flashcard/data/services/flashcard_store.dart';
import '../../data/services/dictionary_service.dart';
import '../../domain/models/ruby_segment.dart';
import 'save_to_deck_sheet.dart';

const _subtitleTextStyle = TextStyle(
  fontFamilyFallback: ['NotoSansJP'],
  fontSize: 15.5,
  fontWeight: FontWeight.bold,
  color: Colors.white,
  height: 1.45,
  letterSpacing: 0.2,
  shadows: [
    Shadow(color: Color(0x99000000), offset: Offset(0, 1), blurRadius: 4.0),
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
    if (_selected == null) return;
    setState(() {
      _selected = null;
      _selectedIndex = null;
    });
    widget.onLookupActiveChanged?.call(false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme ?? const AdaptiveVideoTheme(isLight: false);
    final selected = _selected;

    return Column(
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
              onClose: _clearSelection,
            ),
          ),
          const SizedBox(height: 8.0),
        ],
        // Giới hạn khu vực phụ đề không chiếm quá 35% chiều cao màn hình
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
                    color: Colors.white.withValues(alpha: 0.85),
                    height: 1.4,
                    letterSpacing: 0.1,
                    shadows: const [
                      Shadow(
                        color: Color(0x80000000),
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
              shadows: const [
                Shadow(
                  color: Color(0x80000000),
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

/// Bảng tra từ: cách đọc, từ gốc, nghĩa, từ loại, cấp JLPT, phát âm và
/// lưu Flashcard.
class _WordLookupCard extends StatefulWidget {
  final SubtitleToken token;
  final String sentence;
  final VoidCallback onClose;

  const _WordLookupCard({
    super.key,
    required this.token,
    required this.sentence,
    required this.onClose,
  });

  @override
  State<_WordLookupCard> createState() => _WordLookupCardState();
}

class _WordLookupCardState extends State<_WordLookupCard> {
  // Kích thước và màu dùng chung để bảng đồng nhất.
  static const double _cardWidth = 280.0;
  static const double _cardMinHeight = 148.0;
  static const Color _cardColor = Color(0xFF1C1C1E);
  static const Color _mutedText = Color(0xFF9A9AA0);

  /// Những từ đã lưu trong phiên này: từ -> {khoá bộ thẻ -> tên bộ}.
  /// Dùng để không lưu trùng một từ vào cùng một bộ.
  static final Map<String, Map<String, String>> _savedDecks = {};

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

  /// Mở bảng chọn bộ thẻ, rồi lưu từ vào bộ được chọn.
  Future<void> _chooseAndSave(WordLookup word) async {
    if (_isSaving) return;
    final choice = await showSaveToDeckSheet(
      context,
      savedKeys: (_savedDecks[word.term] ?? const {}).keys.toSet(),
    );
    if (choice == null || !mounted) return;
    await _saveTo(word, choice);
  }

  Future<void> _saveTo(WordLookup word, DeckChoice choice) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final example = widget.sentence.isNotEmpty ? widget.sentence : null;
      if (choice.setId == null) {
        // Bộ mặc định "Từ vựng đã lưu từ Video": backend tự tạo nếu chưa có.
        await FlashcardService.instance.saveVideoVocab(
          term: word.term,
          reading: word.reading,
          meaning: word.meaning,
          example: example,
        );
      } else {
        await FlashcardService.instance.addCard(
          choice.setId!,
          term: word.term,
          reading: word.reading,
          meaning: word.meaning,
          example: example,
        );
      }
      (_savedDecks[word.term] ??= {})[choice.key] = choice.title;
      // Để Thư viện thẻ nạp lại số thuật ngữ của các bộ.
      FlashcardStore.instance.invalidateAll();
      if (!mounted) return;
      _showSnackBar('Đã lưu "${word.term}" vào "${choice.title}"');
    } on ApiException catch (e) {
      if (mounted) _showSnackBar(e.message, isError: true);
    } catch (_) {
      if (mounted) _showSnackBar('Không lưu được từ. Vui lòng thử lại.', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (isError) {
      AppToast.showError(message, context: context);
    } else {
      AppToast.showSuccess(message, context: context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _cardWidth,
      constraints: const BoxConstraints(minHeight: _cardMinHeight),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 14),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16.0),
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
          final loading = snapshot.connectionState != ConnectionState.done;
          final word = snapshot.data;
          final failed =
              !loading && (snapshot.hasError || word == null || !word.found);

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(loading ? null : word),
              const SizedBox(height: 8),
              if (loading)
                _buildLoadingBody()
              else if (failed)
                _buildNotFoundBody()
              else
                _buildMeaning(word!),
              if (!loading && !failed) ...[
                const SizedBox(height: 12),
                const Divider(height: 1, color: Colors.white12),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _buildSaveButton(word!),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  /// Hàng đầu: [cách đọc nhỏ + từ lớn + 🔊] bên trái, [JLPT + ✕] bên phải.
  Widget _buildHeader(WordLookup? word) {
    final term = word != null && word.term.isNotEmpty
        ? word.term
        : widget.token.baseForm;
    final reading = word != null && word.reading.isNotEmpty
        ? word.reading
        : widget.token.reading;
    final showReading = reading.isNotEmpty && reading != term;
    final surface = widget.token.surface;
    final jlpt = word?.jlptLevel ?? '';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showReading)
                Text(
                  reading,
                  style: const TextStyle(
                    fontSize: 12,
                    color: _mutedText,
                    height: 1.2,
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      term,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkResponse(
                    onTap: () => TtsService.speak(text: term),
                    radius: 18,
                    child: const SizedBox(
                      width: 28,
                      height: 28,
                      child: Icon(
                        Icons.volume_up_rounded,
                        size: 20,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),
              if (surface != term && surface.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'dạng gốc của $surface',
                    style: const TextStyle(fontSize: 11, color: _mutedText),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (jlpt.isNotEmpty) _buildJlptBadge(jlpt),
            InkResponse(
              onTap: widget.onClose,
              radius: 18,
              child: const SizedBox(
                width: 32,
                height: 28,
                child: Icon(Icons.close_rounded, size: 20, color: _mutedText),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildJlptBadge(String level) {
    return Container(
      margin: const EdgeInsets.only(right: 2),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _accent.withValues(alpha: 0.6)),
      ),
      child: Text(
        level,
        style: const TextStyle(
          color: _accent,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// Chip từ loại + nghĩa (tối đa 2 dòng).
  Widget _buildMeaning(WordLookup word) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Text.rich(
        TextSpan(
          children: [
            if (word.partOfSpeech.isNotEmpty)
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    word.partOfSpeech,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            TextSpan(
              text: word.meaning,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                height: 1.4,
              ),
            ),
          ],
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  /// Khung xám giữ đúng chiều cao để bảng không nhảy khi có kết quả.
  Widget _buildLoadingBody() {
    Widget bar(double width) => Container(
      width: width,
      height: 12,
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(6),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(right: 8, top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          bar(190),
          const SizedBox(height: 8),
          bar(120),
          const SizedBox(height: 22),
          Container(
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotFoundBody() {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Không tìm thấy nghĩa của từ này.',
              style: TextStyle(color: _mutedText, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: _retry,
            child: const Text('Thử lại', style: TextStyle(color: _accent)),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton(WordLookup word) {
    final isSaved = (_savedDecks[word.term] ?? const {}).isNotEmpty;

    return SizedBox(
      width: double.infinity,
      height: 36,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: isSaved ? Colors.white12 : _accent,
          disabledBackgroundColor: isSaved
              ? Colors.white12
              : _accent.withValues(alpha: 0.6),
          elevation: 0,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        // Đã lưu vẫn bấm được để lưu thêm vào bộ khác.
        onPressed: _isSaving ? null : () => _chooseAndSave(word),
        icon: _isSaving
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(
                isSaved ? Icons.check_rounded : Icons.add_rounded,
                size: 18,
                color: isSaved ? Colors.white70 : Colors.white,
              ),
        label: Text(
          isSaved ? 'Đã lưu · Lưu vào bộ khác' : 'Lưu vào Flashcard',
          style: TextStyle(
            color: isSaved ? Colors.white70 : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13.5,
          ),
        ),
      ),
    );
  }
}
