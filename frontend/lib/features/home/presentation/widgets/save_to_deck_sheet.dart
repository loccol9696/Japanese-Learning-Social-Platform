import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../flashcard/data/models/flashcard_set_model.dart';
import '../../../flashcard/data/services/flashcard_service.dart';
import '../../../flashcard/data/services/flashcard_store.dart';
import '../../../../core/theme/app_palette.dart';

/// Bộ thẻ người dùng chọn để lưu từ vựng.
class DeckChoice {
  /// Khoá ổn định để nhớ "từ này đã lưu vào bộ nào": `video` cho bộ
  /// "Từ vựng đã lưu từ Video", `id:<setId>` cho các bộ còn lại.
  final String key;

  /// null = bộ "Từ vựng đã lưu từ Video" (backend tự tạo nếu chưa có).
  final int? setId;
  final String title;

  const DeckChoice({
    required this.key,
    required this.setId,
    required this.title,
  });

  static const String videoKey = 'video';

  factory DeckChoice.fromSet(FlashcardSetModel set) {
    return DeckChoice(
      key: set.isVideoSaved ? videoKey : 'id:${set.setId}',
      setId: set.setId,
      title: set.title,
    );
  }
}

/// Hiện bảng chọn bộ thẻ. Trả về bộ được chọn, hoặc null nếu người dùng đóng.
/// [savedKeys] là các bộ đã chứa từ này (hiện dấu ✓ và không cho chọn lại).
Future<DeckChoice?> showSaveToDeckSheet(
  BuildContext context, {
  Set<String> savedKeys = const {},
}) {
  return showModalBottomSheet<DeckChoice>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: AppPalette.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _SaveToDeckSheet(savedKeys: savedKeys),
  );
}

class _SaveToDeckSheet extends StatefulWidget {
  final Set<String> savedKeys;

  const _SaveToDeckSheet({required this.savedKeys});

  @override
  State<_SaveToDeckSheet> createState() => _SaveToDeckSheetState();
}

class _SaveToDeckSheetState extends State<_SaveToDeckSheet> {
  static Color get _accent => AppPalette.accent;
  static Color get _muted => AppPalette.textSecondary;

  late Future<List<FlashcardSetModel>> _setsFuture;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _setsFuture = _loadSets();
  }

  Future<List<FlashcardSetModel>> _loadSets() {
    return FlashcardStore.instance.getSets(forceRefresh: true);
  }

  void _reload() {
    setState(() => _setsFuture = _loadSets());
  }

  Future<void> _createDeck() async {
    final title = await _askDeckTitle();
    if (title == null || !mounted) return;

    setState(() => _isCreating = true);
    try {
      final created = await FlashcardService.instance.createSet(
        title: title,
        isPublic: false,
      );
      FlashcardStore.instance.invalidateAll();
      if (!mounted) return;
      Navigator.of(context).pop(DeckChoice.fromSet(created));
    } on ApiException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Không tạo được bộ thẻ. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    AppToast.showError(message, context: context);
  }

  Future<String?> _askDeckTitle() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        String? error;
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            void submit() {
              final value = controller.text.trim();
              if (value.isEmpty) {
                setDialogState(() => error = 'Vui lòng nhập tên bộ thẻ');
                return;
              }
              Navigator.of(dialogContext).pop(value);
            }

            return AlertDialog(
              backgroundColor: AppPalette.surfaceHigh,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'Tạo bộ thẻ mới',
                style: TextStyle(color: AppPalette.textPrimary, fontSize: 18),
              ),
              content: TextField(
                controller: controller,
                autofocus: true,
                maxLength: 100,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => submit(),
                style: TextStyle(color: AppPalette.textPrimary),
                cursorColor: _accent,
                decoration: InputDecoration(
                  hintText: 'Tên bộ thẻ',
                  hintStyle: TextStyle(color: _muted),
                  errorText: error,
                  counterStyle: TextStyle(color: _muted),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: AppPalette.border),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: _accent),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text('Hủy', style: TextStyle(color: _muted)),
                ),
                TextButton(
                  onPressed: submit,
                  child: Text(
                    'Tạo và lưu',
                    style: TextStyle(
                      color: _accent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(controller.dispose);
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.7;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            Divider(height: 1, color: AppPalette.border),
            Flexible(
              child: FutureBuilder<List<FlashcardSetModel>>(
                future: _setsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: CircularProgressIndicator(color: _accent),
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return _buildError();
                  }
                  return _buildList(snapshot.data ?? const []);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Lưu vào bộ thẻ',
              style: TextStyle(
                color: AppPalette.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, color: _muted),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Không tải được danh sách bộ thẻ.',
            style: TextStyle(color: _muted),
          ),
          TextButton(
            onPressed: _reload,
            child: Text('Thử lại', style: TextStyle(color: _accent)),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<FlashcardSetModel> sets) {
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: 12),
      children: [
        ListTile(
          enabled: !_isCreating,
          leading: _isCreating
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _accent,
                  ),
                )
              : Icon(Icons.add_circle_outline_rounded, color: _accent),
          title: Text(
            'Tạo bộ thẻ mới',
            style: TextStyle(color: _accent, fontWeight: FontWeight.w600),
          ),
          onTap: _createDeck,
        ),
        Divider(height: 1, color: AppPalette.border),
        if (sets.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Text(
              'Bạn chưa có bộ thẻ nào. Hãy tạo bộ thẻ mới để lưu từ.',
              style: TextStyle(color: _muted),
            ),
          ),
        for (final set in sets)
          _buildDeckTile(
            choice: DeckChoice.fromSet(set),
            subtitle: '${set.totalCards} thuật ngữ',
            icon: set.isVideoSaved
                ? Icons.video_library_outlined
                : Icons.style_outlined,
          ),
      ],
    );
  }

  Widget _buildDeckTile({
    required DeckChoice choice,
    required String subtitle,
    required IconData icon,
  }) {
    final alreadySaved = widget.savedKeys.contains(choice.key);

    return ListTile(
      enabled: !_isCreating && !alreadySaved,
      leading: Icon(icon, color: alreadySaved ? _muted : AppPalette.textSecondary),
      title: Text(
        choice.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: alreadySaved ? _muted : AppPalette.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        alreadySaved ? 'Từ này đã có trong bộ' : subtitle,
        style: TextStyle(color: _muted, fontSize: 12),
      ),
      trailing: alreadySaved
          ? Icon(Icons.check_rounded, color: _muted)
          : null,
      onTap: () => Navigator.of(context).pop(choice),
    );
  }
}
