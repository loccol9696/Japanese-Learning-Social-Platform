import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../home/data/services/dictionary_service.dart';
import '../../../home/presentation/widgets/word_lookup_card.dart';

/// Mở bảng học tin nhắn tiếng Nhật: câu có furigana, bấm từng từ để tra và lưu Flashcard.
Future<void> showMessageStudySheet(BuildContext context, String text) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppPalette.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => MessageStudySheet(text: text),
  );
}

class MessageStudySheet extends StatefulWidget {
  final String text;

  const MessageStudySheet({super.key, required this.text});

  @override
  State<MessageStudySheet> createState() => _MessageStudySheetState();
}

class _MessageStudySheetState extends State<MessageStudySheet> {
  static final RegExp _kanji = RegExp(r'[㐀-鿿]');

  late Future<List<SubtitleToken>> _tokens = _load();
  int? _selectedIndex;
  SubtitleToken? _selected;

  Future<List<SubtitleToken>> _load() =>
      DictionaryService.instance.tokenize(widget.text);

  void _toggle(SubtitleToken token, int index) {
    setState(() {
      final same = _selectedIndex == index;
      _selectedIndex = same ? null : index;
      _selected = same ? null : token;
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedIndex = null;
      _selected = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bấm vào từ để xem nghĩa',
            style: TextStyle(color: AppPalette.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<SubtitleToken>>(
            future: _tokens,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              final tokens = snapshot.data;
              if (snapshot.hasError || tokens == null || tokens.isEmpty) {
                return _buildFallback();
              }
              return Wrap(
                crossAxisAlignment: WrapCrossAlignment.end,
                spacing: 2,
                runSpacing: 6,
                children: [
                  for (var i = 0; i < tokens.length; i++)
                    _buildToken(tokens[i], i),
                ],
              );
            },
          ),
          if (_selected != null) ...[
            const SizedBox(height: 16),
            Center(
              child: WordLookupCard(
                key: ValueKey(_selected!.baseForm),
                token: _selected!,
                sentence: widget.text,
                onClose: _clearSelection,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Không tách được câu: vẫn hiện nguyên văn và cho thử lại.
  Widget _buildFallback() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.text,
          style: TextStyle(color: AppPalette.textPrimary, fontSize: 18),
        ),
        TextButton(
          onPressed: () => setState(() => _tokens = _load()),
          child: Text('Thử lại', style: TextStyle(color: AppPalette.accent)),
        ),
      ],
    );
  }

  Widget _buildToken(SubtitleToken token, int index) {
    final showReading =
        _kanji.hasMatch(token.surface) &&
        token.reading.isNotEmpty &&
        token.reading != token.surface;
    final selected = _selectedIndex == index;

    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
      decoration: BoxDecoration(
        color: selected
            ? AppPalette.accent.withValues(alpha: 0.3)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showReading)
            Text(
              token.reading,
              style: TextStyle(color: AppPalette.textSecondary, fontSize: 11),
            ),
          Text(
            token.surface,
            style: TextStyle(
              color: AppPalette.textPrimary,
              fontSize: 20,
              fontFamilyFallback: const ['NotoSansJP'],
            ),
          ),
        ],
      ),
    );

    if (!token.lookupable) return content;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _toggle(token, index),
      child: content,
    );
  }
}
