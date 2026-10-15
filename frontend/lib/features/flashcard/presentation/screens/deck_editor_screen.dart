import 'package:flutter/material.dart';
import '../../data/models/flashcard_set_model.dart';
import '../../data/services/flashcard_service.dart';
import '../../data/services/flashcard_store.dart';

class DeckEditorScreen extends StatefulWidget {
  final FlashcardSetModel? deck;

  const DeckEditorScreen({super.key, this.deck});

  @override
  State<DeckEditorScreen> createState() => _DeckEditorScreenState();
}

class _CardDraft {
  final int? cardId;
  final TextEditingController termController;
  final TextEditingController meaningController;

  _CardDraft({
    this.cardId,
    required String term,
    required String meaning,
  })  : termController = TextEditingController(text: term),
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

  final List<_CardDraft> _cards = [];
  final List<int> _deletedCardIds = [];

  bool _isLoading = true;
  bool _isSaving = false;

  bool get _isEditing => widget.deck != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.deck?.title ?? '');
    _descController =
        TextEditingController(text: widget.deck?.description ?? '');
    if (_isEditing) {
      _loadInitialCards();
    } else {
      _isLoading = false;
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
            _cards.add(
              _CardDraft(
                cardId: item.cardId,
                term: item.term,
                meaning: item.meaning,
              ),
            );
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
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

  void _removeCard(int index) {
    final removed = _cards.removeAt(index);
    if (removed.cardId != null) {
      _deletedCardIds.add(removed.cardId!);
    }
    removed.dispose();
    setState(() {});
  }

  Future<void> _saveDeck() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập tiêu đề bộ thẻ'),
          backgroundColor: Color(0xFF252632),
          behavior: SnackBarBehavior.floating,
        ),
      );
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
        for (final card in _cards) {
          final term = card.termController.text.trim();
          final meaning = card.meaningController.text.trim();

          // Bỏ qua các thẻ để trống cả thuật ngữ và định nghĩa
          if (term.isEmpty && meaning.isEmpty) continue;

          if (card.cardId == null) {
            // Thẻ mới thêm
            await _service.addCard(
              widget.deck!.setId,
              term: term.isEmpty ? 'Chưa đặt tên' : term,
              reading: '',
              meaning: meaning.isEmpty ? 'Chưa có định nghĩa' : meaning,
            );
          } else {
            // Thẻ hiện có đã chỉnh sửa
            await _service.updateCard(
              card.cardId!,
              term: term.isEmpty ? 'Chưa đặt tên' : term,
              meaning: meaning.isEmpty ? 'Chưa có định nghĩa' : meaning,
            );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing
                  ? 'Đã lưu thay đổi bộ thẻ thành công'
                  : 'Đã tạo bộ thẻ mới thành công',
            ),
            backgroundColor: const Color(0xFF252632),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing
                  ? 'Không thể lưu bộ thẻ: $e'
                  : 'Không thể tạo bộ thẻ: $e',
            ),
            backgroundColor: const Color(0xFFFF5A5F),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEditing ? 'Chỉnh sửa bộ thẻ' : 'Tạo bộ thẻ mới',
          style: const TextStyle(
            color: Colors.white,
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
                  backgroundColor: const Color(0xFFFF5A5F),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFFF5A5F).withOpacity(0.5),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  minimumSize: const Size(60, 36),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
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
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF5A5F)),
            )
          : ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
              children: [
                // 2. Thông tin chung của bộ thẻ (Top Section)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1F28),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.04),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tiêu đề bộ thẻ
                      TextField(
                        controller: _titleController,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Tiêu đề bộ thẻ...',
                          hintStyle: const TextStyle(
                            color: Color(0xFF73768A),
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                          ),
                          filled: true,
                          fillColor: const Color(0xFF121215),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Color(0xFF2E3140),
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Color(0xFF4E526B),
                              width: 1,
                            ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Color(0xFF2E3140),
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Thêm mô tả...',
                          hintStyle: const TextStyle(
                            color: Color(0xFF73768A),
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                          filled: true,
                          fillColor: const Color(0xFF121215),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Color(0xFF2E3140),
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Color(0xFF4E526B),
                              width: 1,
                            ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Color(0xFF2E3140),
                              width: 1,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 3. Danh sách từ vựng (Card Items)
                ...List.generate(_cards.length, (index) {
                  final card = _cards[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1F28),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.04),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Hàng đầu: Số thứ tự nhỏ + Icon thùng rác [🗑]
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: Color(0xFF8E8E93),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              IconButton(
                                constraints: const BoxConstraints(
                                  minWidth: 36,
                                  minHeight: 36,
                                ),
                                padding: EdgeInsets.zero,
                                splashRadius: 18,
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: Color(0xFF8E8E93),
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
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Thuật ngữ...',
                              hintStyle: const TextStyle(
                                color: Color(0xFF73768A),
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                                height: 1.4,
                              ),
                              filled: true,
                              fillColor: const Color(0xFF121215),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Color(0xFF2E3140),
                                  width: 1,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Color(0xFF4E526B),
                                  width: 1,
                                ),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Color(0xFF2E3140),
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
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                              height: 1.4,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Định nghĩa...',
                              hintStyle: const TextStyle(
                                color: Color(0xFF73768A),
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                                height: 1.4,
                              ),
                              filled: true,
                              fillColor: const Color(0xFF121215),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Color(0xFF2E3140),
                                  width: 1,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Color(0xFF4E526B),
                                  width: 1,
                                ),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Color(0xFF2E3140),
                                  width: 1,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 8),

                // 4. Nút thêm từ (Bottom Action)
                InkWell(
                  onTap: _addNewCard,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1F28),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.06),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'Thêm thẻ',
                      style: TextStyle(
                        color: Color(0xFFA0A0B0),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
