import 'package:flutter/material.dart';

import '../../../../core/auth/auth_guard.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/services/tts_service.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../flashcard/data/services/flashcard_service.dart';
import '../../../flashcard/data/services/flashcard_store.dart';
import '../../data/services/dictionary_service.dart';
import 'save_to_deck_sheet.dart';

Color get _accent => AppPalette.accent;

/// Bảng tra từ: cách đọc, từ gốc, nghĩa, từ loại, cấp JLPT, phát âm và
/// lưu Flashcard.
class WordLookupCard extends StatefulWidget {
  final SubtitleToken token;

  /// Câu chứa từ này, lưu làm ví dụ khi thêm vào Flashcard.
  final String sentence;
  final VoidCallback onClose;

  const WordLookupCard({
    super.key,
    required this.token,
    required this.sentence,
    required this.onClose,
  });

  @override
  State<WordLookupCard> createState() => _WordLookupCardState();
}

class _WordLookupCardState extends State<WordLookupCard> {
  // Kích thước và màu dùng chung để bảng đồng nhất.
  static const double _cardWidth = 280.0;
  static const double _cardMinHeight = 148.0;
  static Color get _cardColor => AppPalette.surface;
  static Color get _mutedText => AppPalette.textSecondary;

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
    if (!await requireAuthentication(
      context,
      message: 'Bạn cần đăng nhập để lưu từ vựng vào bộ thẻ Flashcard và đồng bộ tiến trình học.',
    )) {
      return;
    }
    if (!mounted) return;

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
      if (mounted) {
        _showSnackBar('Không lưu được từ. Vui lòng thử lại.', isError: true);
      }
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
        border: Border.all(color: AppPalette.border),
        boxShadow: [
          BoxShadow(
            color: AppPalette.shadow,
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
                Divider(height: 1, color: AppPalette.border),
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
                  style: TextStyle(
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
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppPalette.textPrimary,
                        height: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkResponse(
                    onTap: () => TtsService.speak(text: term),
                    radius: 18,
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: Icon(
                        Icons.volume_up_rounded,
                        size: 20,
                        color: AppPalette.textSecondary,
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
                    style: TextStyle(fontSize: 11, color: _mutedText),
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
              child: SizedBox(
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
        style: TextStyle(
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
                    color: AppPalette.border,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    word.partOfSpeech,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppPalette.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            TextSpan(
              text: word.meaning,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppPalette.textPrimary,
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
        color: AppPalette.border,
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
              color: AppPalette.border,
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
          Expanded(
            child: Text(
              'Không tìm thấy nghĩa của từ này.',
              style: TextStyle(color: _mutedText, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: _retry,
            child: Text('Thử lại', style: TextStyle(color: _accent)),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton(WordLookup word) {
    final isSaved = (_savedDecks[word.term] ?? const {}).isNotEmpty;

    return Align(
      alignment: Alignment.centerLeft,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: isSaved ? AppPalette.border : _accent,
          disabledBackgroundColor: isSaved
              ? AppPalette.border
              : _accent.withValues(alpha: 0.6),
          elevation: 0,
          minimumSize: const Size(0, 38),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        // Đã lưu vẫn bấm được để lưu thêm vào bộ khác.
        onPressed: _isSaving ? null : () => _chooseAndSave(word),
        icon: _isSaving
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppPalette.textPrimary,
                ),
              )
            : Icon(
                isSaved ? Icons.check_rounded : Icons.add_rounded,
                size: 17,
                color: isSaved
                    ? AppPalette.textSecondary
                    : AppPalette.textPrimary,
              ),
        label: Text(
          isSaved ? 'Đã lưu · Lưu vào bộ khác' : 'Lưu vào Flashcard',
          style: TextStyle(
            color: isSaved ? AppPalette.textSecondary : AppPalette.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 13.5,
          ),
        ),
      ),
    );
  }
}
