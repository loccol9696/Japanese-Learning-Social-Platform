import 'package:flutter/material.dart';

import '../../data/models/flashcard_set_model.dart';
import '../../data/services/flashcard_service.dart';
import '../../data/services/flashcard_store.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/app_toast.dart';

class DeckEditorScreen extends StatefulWidget {
  final FlashcardSetModel? deck;

  const DeckEditorScreen({super.key, this.deck});

  @override
  State<DeckEditorScreen> createState() => _DeckEditorScreenState();
}

class _CardDraft {
  final int? cardId;
  final Key key = UniqueKey();
  final TextEditingController termController;
  final TextEditingController meaningController;

  _CardDraft({this.cardId, required String term, required String meaning})
    : termController = TextEditingController(text: term),
      meaningController = TextEditingController(text: meaning);

  void dispose() {
    termController.dispose();
    meaningController.dispose();
  }
}

class _DeckEditorScreenState extends State<DeckEditorScreen> {
  final FlashcardService _service = FlashcardService.instance;
  final ScrollController _scrollController = ScrollController();

  late final TextEditingController _titleController;
  late final TextEditingController _descController;

  /// Số ô thẻ trống để sẵn khi bộ chưa có thuật ngữ nào, để người dùng nhập ngay không cần bấm "Thêm thẻ".
  static const int _starterCardCount = 2;

  final List<_CardDraft> _cards = [];
  final List<int> _deletedCardIds = [];

  /// Thứ tự id các thẻ lúc mở bộ; so với thứ tự lúc lưu để biết có cần gọi API sắp xếp không.
  final List<int> _initialOrder = [];

  bool _isLoading = true;
  bool _isSaving = false;

  bool get _isEditing => widget.deck != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.deck?.title ?? '');
    _descController = TextEditingController(
      text: widget.deck?.description ?? '',
    );
    if (_isEditing) {
      _loadInitialCards();
    } else {
      _ensureStarterCards();
      _isLoading = false;
    }
  }

  /// Chưa có thẻ nào thì để sẵn [_starterCardCount] ô trống. Ô trống cả thuật ngữ lẫn định nghĩa sẽ bị bỏ qua khi
  /// lưu nên không tạo thẻ rác. Đã có thẻ (kể cả chỉ một ô trống) thì giữ nguyên.
  void _ensureStarterCards() {
    if (_cards.isNotEmpty) return;
    for (var i = 0; i < _starterCardCount; i++) {
      _cards.add(_CardDraft(term: '', meaning: ''));
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _scrollController.dispose();
    for (var card in _cards) {
      card.dispose();
    }
    super.dispose();
  }

  Future<void> _loadInitialCards() async {
    if (widget.deck == null) return;
    try {
      final items = await _service.getCardsInSet(widget.deck!.setId);
      if (mounted) {
        setState(() {
          for (var item in items) {
            _initialOrder.add(item.cardId);
            _cards.add(
              _CardDraft(
                cardId: item.cardId,
                term: item.term,
                meaning: item.meaning,
              ),
            );
          }
          _ensureStarterCards();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _ensureStarterCards();
          _isLoading = false;
        });
      }
    }
  }

  void _addNewCard() {
    setState(() {
      _cards.add(_CardDraft(term: '', meaning: ''));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 140,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _onReorderCards(int oldIndex, int newIndex) {
    if (newIndex == oldIndex) return;
    setState(() => _cards.insert(newIndex, _cards.removeAt(oldIndex)));
  }

  void _removeCard(int index) {
    final removed = _cards.removeAt(index);
    if (removed.cardId != null) {
      _deletedCardIds.add(removed.cardId!);
    }
    removed.dispose();
    // Xoá hết thẻ thì để lại ô trống sẵn như lúc mới tạo.
    setState(_ensureStarterCards);
  }

  static bool _sameOrder(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<void> _saveDeck() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      AppToast.showError('Vui lòng nhập tiêu đề bộ thẻ', context: context);
      return;
    }

    setState(() => _isSaving = true);

    try {
      if (_isEditing) {
        // 1. Cập nhật thông tin tiêu đề và mô tả của bộ thẻ
        await _service.updateSet(
          widget.deck!.setId,
          title: title,
          description: _descController.text.trim().isEmpty
              ? null
              : _descController.text.trim(),
        );

        // 2. Xóa các thẻ đã bị loại bỏ
        for (final cardId in _deletedCardIds) {
          try {
            await _service.deleteCard(cardId);
          } catch (_) {}
        }

        // 3. Thêm mới hoặc cập nhật các thẻ trong danh sách
        final orderedIds = <int>[];
        for (final card in _cards) {
          final term = card.termController.text.trim();
          final meaning = card.meaningController.text.trim();

          // Bỏ qua các thẻ để trống cả thuật ngữ và định nghĩa
          if (term.isEmpty && meaning.isEmpty) continue;

          if (card.cardId == null) {
            // Thẻ mới thêm
            final created = await _service.addCard(
              widget.deck!.setId,
              term: term.isEmpty ? 'Chưa đặt tên' : term,
              reading: '',
              meaning: meaning.isEmpty ? 'Chưa có định nghĩa' : meaning,
            );
            orderedIds.add(created.cardId);
          } else {
            orderedIds.add(card.cardId!);
            // Thẻ hiện có đã chỉnh sửa
            await _service.updateCard(
              card.cardId!,
              term: term.isEmpty ? 'Chưa đặt tên' : term,
              meaning: meaning.isEmpty ? 'Chưa có định nghĩa' : meaning,
            );
          }
        }

        // 4. Lưu thứ tự khi người dùng kéo đổi chỗ hoặc chèn thẻ mới vào giữa (mặc định thẻ mới nằm cuối).
        final defaultOrder = [
          ..._initialOrder.where(orderedIds.contains),
          ...orderedIds.where((id) => !_initialOrder.contains(id)),
        ];
        if (orderedIds.length > 1 && !_sameOrder(orderedIds, defaultOrder)) {
          try {
            await _service.reorderCards(widget.deck!.setId, orderedIds);
          } catch (_) {
            // Nội dung đã lưu; chỉ thứ tự chưa lưu được, không coi là lỗi cả lần lưu.
          }
        }
      } else {
        // Tạo bộ thẻ mới
        final createdSet = await _service.createSet(
          title: title,
          description: _descController.text.trim().isEmpty
              ? null
              : _descController.text.trim(),
        );

        // Thêm các thẻ nếu người dùng đã tạo trong trang
        for (final card in _cards) {
          final term = card.termController.text.trim();
          final meaning = card.meaningController.text.trim();

          if (term.isEmpty && meaning.isEmpty) continue;

          await _service.addCard(
            createdSet.setId,
            term: term.isEmpty ? 'Chưa đặt tên' : term,
            reading: '',
            meaning: meaning.isEmpty ? 'Chưa có định nghĩa' : meaning,
          );
        }

        FlashcardStore.instance.updateSetInCache(createdSet);
        FlashcardStore.instance.invalidateSet(createdSet.setId);
      }

      if (_isEditing) {
        FlashcardStore.instance.updateSetInCache(
          widget.deck!.copyWith(
            title: title,
            description: _descController.text.trim().isEmpty
                ? null
                : _descController.text.trim(),
          ),
        );
        FlashcardStore.instance.invalidateSet(widget.deck!.setId);
      }

      if (mounted) {
        AppToast.showSuccess(
          _isEditing
              ? 'Đã lưu thay đổi bộ thẻ thành công'
              : 'Đã tạo bộ thẻ mới thành công',
          context: context,
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        AppToast.showError(
          _isEditing ? 'Không thể lưu bộ thẻ: $e' : 'Không thể tạo bộ thẻ: $e',
          context: context,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        backgroundColor: AppPalette.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppPalette.textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEditing ? 'Chỉnh sửa bộ thẻ' : 'Tạo bộ thẻ mới',
          style: TextStyle(
            color: AppPalette.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveDeck,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppPalette.accent,
                  foregroundColor: AppPalette.onAccent,
                  disabledBackgroundColor: AppPalette.accent.withOpacity(0.5),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 8,
                  ),
                  minimumSize: const Size(60, 36),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: _isSaving
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: AppPalette.textPrimary,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Lưu',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppPalette.accent))
          : CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // 2. Thông tin chung của bộ thẻ (Top Section)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppPalette.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppPalette.textPrimary.withValues(
                              alpha: 0.04,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Tiêu đề bộ thẻ
                            TextField(
                              controller: _titleController,
                              style: TextStyle(
                                color: AppPalette.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Tiêu đề bộ thẻ...',
                                hintStyle: TextStyle(
                                  color: AppPalette.textSecondary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w400,
                                ),
                                filled: true,
                                fillColor: AppPalette.background,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: AppPalette.border,
                                    width: 1,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: AppPalette.textSecondary,
                                    width: 1,
                                  ),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: AppPalette.border,
                                    width: 1,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            // Mô tả bộ thẻ
                            TextField(
                              controller: _descController,
                              maxLines: 3,
                              minLines: 2,
                              style: TextStyle(
                                color: AppPalette.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Thêm mô tả...',
                                hintStyle: TextStyle(
                                  color: AppPalette.textSecondary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                ),
                                filled: true,
                                fillColor: AppPalette.background,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: AppPalette.border,
                                    width: 1,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: AppPalette.textSecondary,
                                    width: 1,
                                  ),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: AppPalette.border,
                                    width: 1,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),
                    ]),
                  ),
                ),

                // 3. Danh sách từ vựng (Card Items), kéo biểu tượng ⠿ để đổi chỗ
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverReorderableList(
                    itemCount: _cards.length,
                    onReorderItem: _onReorderCards,
                    proxyDecorator: (child, index, animation) =>
                        Material(color: Colors.transparent, child: child),
                    itemBuilder: (context, index) {
                      final card = _cards[index];
                      return Padding(
                        key: card.key,
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Container(
                          key: ValueKey('card-draft-$index'),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppPalette.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppPalette.textPrimary.withValues(
                                alpha: 0.04,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Hàng đầu: Số thứ tự nhỏ + Icon thùng rác [🗑]
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      ReorderableDragStartListener(
                                        index: index,
                                        child: Padding(
                                          key: ValueKey(
                                            'card-drag-handle-$index',
                                          ),
                                          padding: const EdgeInsets.only(
                                            right: 8,
                                          ),
                                          child: Icon(
                                            Icons.drag_indicator_rounded,
                                            color: AppPalette.textSecondary,
                                            size: 22,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '${index + 1}',
                                        style: TextStyle(
                                          color: AppPalette.textSecondary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  IconButton(
                                    constraints: const BoxConstraints(
                                      minWidth: 36,
                                      minHeight: 36,
                                    ),
                                    padding: EdgeInsets.zero,
                                    splashRadius: 18,
                                    icon: Icon(
                                      Icons.delete_outline_rounded,
                                      color: AppPalette.textSecondary,
                                      size: 20,
                                    ),
                                    onPressed: () => _removeCard(index),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // Ô nhập Thuật ngữ
                              TextField(
                                controller: card.termController,
                                maxLines: null,
                                minLines: 1,
                                keyboardType: TextInputType.multiline,
                                style: TextStyle(
                                  color: AppPalette.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  height: 1.4,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Thuật ngữ...',
                                  hintStyle: TextStyle(
                                    color: AppPalette.textSecondary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w400,
                                    height: 1.4,
                                  ),
                                  filled: true,
                                  fillColor: AppPalette.background,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: AppPalette.border,
                                      width: 1,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: AppPalette.textSecondary,
                                      width: 1,
                                    ),
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: AppPalette.border,
                                      width: 1,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 10),

                              // Ô nhập Định nghĩa
                              TextField(
                                controller: card.meaningController,
                                maxLines: null,
                                minLines: 1,
                                keyboardType: TextInputType.multiline,
                                style: TextStyle(
                                  color: AppPalette.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w400,
                                  height: 1.4,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Định nghĩa...',
                                  hintStyle: TextStyle(
                                    color: AppPalette.textSecondary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w400,
                                    height: 1.4,
                                  ),
                                  filled: true,
                                  fillColor: AppPalette.background,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: AppPalette.border,
                                      width: 1,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: AppPalette.textSecondary,
                                      width: 1,
                                    ),
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: AppPalette.border,
                                      width: 1,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // 4. Nút thêm từ (Bottom Action)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  sliver: SliverToBoxAdapter(
                    child: InkWell(
                      onTap: _addNewCard,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppPalette.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppPalette.textPrimary.withValues(
                              alpha: 0.06,
                            ),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Thêm thẻ',
                          style: TextStyle(
                            color: AppPalette.textSecondary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
