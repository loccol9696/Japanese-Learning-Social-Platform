import 'package:flutter/material.dart';

import '../../../../core/auth/auth_guard.dart';
import '../../../auth/data/auth_session.dart';
import '../../data/models/flashcard_set_model.dart';
import '../../data/services/flashcard_service.dart';
import '../../data/services/flashcard_store.dart';
import '../../../../core/widgets/square_add_button.dart';
import '../widgets/deck_card_item.dart';
import 'deck_editor_screen.dart';
import 'deck_overview_screen.dart';
import 'srs_study_screen.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/app_toast.dart';

class DeckLibraryScreen extends StatefulWidget {
  const DeckLibraryScreen({super.key});

  @override
  State<DeckLibraryScreen> createState() => _DeckLibraryScreenState();
}

class _DeckLibraryScreenState extends State<DeckLibraryScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FlashcardStore _store = FlashcardStore.instance;
  final FlashcardService _service = FlashcardService.instance;
  List<FlashcardSetModel> _decks = [];
  bool _isLoading = false;
  int _dueCount = 0;

  @override
  void initState() {
    super.initState();
    AuthSession.instance.addListener(_onAuthChanged);
    _store.addListener(_onStoreUpdated);
    if (!AuthSession.instance.isAuthenticated) return;
    // Cache-First: Lấy ngay từ RAM hiển thị trong 0ms nếu đã có dữ liệu
    _decks = _store.cachedSets ?? [];
    _isLoading = !_store.hasCachedSets();

    _store.addListener(_onStoreUpdated);
    _loadDecks();
  }

  @override
  void dispose() {
    AuthSession.instance.removeListener(_onAuthChanged);
    _store.removeListener(_onStoreUpdated);
    _searchController.dispose();
    super.dispose();
  }

  void _onAuthChanged() {
    if (!mounted) return;
    setState(() {});
    if (AuthSession.instance.isAuthenticated && !_store.hasCachedSets()) {
      _loadDecks();
    }
  }

  void _onStoreUpdated() {
    // Cache bị huỷ (vd. vừa lưu từ vựng từ video): nạp lại thay vì hiển thị rỗng.
    if (mounted &&
        !_store.hasCachedSets() &&
        AuthSession.instance.isAuthenticated) {
      _loadDecks();
      return;
    }
    if (mounted && _searchController.text.trim().isEmpty) {
      setState(() {
        _decks = _store.cachedSets ?? [];
        if (_store.hasCachedSets()) {
          _isLoading = false;
        }
      });
    }
  }

  /// Lấy danh sách bộ thẻ với Stale-While-Revalidate:
  /// - Không bao giờ set _isLoading = true nếu màn hình đã có dữ liệu
  /// - Tự động đồng bộ ngầm và cập nhật êm dịu nếu backend có thay đổi
  Future<void> _loadDecks({String? query, bool forceRefresh = false}) async {
    if (!_store.hasCachedSets() && _decks.isEmpty) {
      setState(() => _isLoading = true);
    }

    final sets = await _store.getSets(
      search: query,
      forceRefresh: forceRefresh,
      onBackgroundUpdated: (updatedList) {
        if (mounted &&
            (_searchController.text.trim().isEmpty || query != null)) {
          setState(() {
            _decks = updatedList;
            _isLoading = false;
          });
        }
      },
    );

    if (mounted) {
      setState(() {
        _decks = sets;
        _isLoading = false;
      });
    }
    _loadDueCount();
  }

  /// Số thẻ đã tới hạn ôn (mọi bộ) cho banner "Cần ôn".
  Future<void> _loadDueCount() async {
    if (!AuthSession.instance.isAuthenticated) return;
    try {
      final summary = await _service.getDueSummary();
      if (mounted && summary.dueCount != _dueCount) {
        setState(() => _dueCount = summary.dueCount);
      }
    } catch (_) {
      // Không có banner nếu không lấy được; không ảnh hưởng danh sách bộ thẻ.
    }
  }

  /// Mở màn hình Chỉnh sửa bộ thẻ (Deck Editor)
  void _openDeckEditor(FlashcardSetModel deck) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => DeckEditorScreen(deck: deck)),
    );
  }

  /// Mở màn hình Tạo bộ thẻ mới (Deck Editor)
  void _openCreateDeck() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DeckEditorScreen()),
    );
  }

  /// Dialog xác nhận xóa bộ thẻ (Confirm Delete Dialog)
  void _showDeleteDeckConfirmDialog(FlashcardSetModel deck) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppPalette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppPalette.border, width: 1),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppPalette.accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.delete_outline_rounded,
                color: AppPalette.accent,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Xác nhận xóa',
                style: TextStyle(
                  color: AppPalette.onAccent,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Bạn có chắc chắn muốn xóa bộ từ vựng "${deck.title}" không?\n\nToàn bộ từ vựng và tiến trình học bên trong sẽ bị xóa vĩnh viễn và không thể khôi phục.',
          style: TextStyle(
            color: AppPalette.textPrimary.withValues(alpha: 0.75),
            fontSize: 14.5,
            height: 1.45,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Hủy',
              style: TextStyle(color: AppPalette.textPrimary.withValues(alpha: 0.65)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppPalette.accent,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            onPressed: () {
              Navigator.pop(ctx);

              // Optimistic Delete: Xóa ngay lập tức trên UI (0ms)
              _store.optimisticDeleteSet(
                deck.setId,
                onError: (err) {
                  if (mounted) {
                    AppToast.showError('Không thể xóa bộ thẻ: $err', context: context);
                  }
                },
              );

              AppToast.showSuccess('Đã xóa bộ thẻ thành công', context: context);
            },
            child: Text(
              'Xóa bộ thẻ',
              style: TextStyle(
                color: AppPalette.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateDeckDialog() {
    final titleController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppPalette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppPalette.border, width: 1),
        ),
        title: Text(
          'Tạo bộ từ vựng mới',
          style: TextStyle(
            color: AppPalette.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: TextField(
          controller: titleController,
          autofocus: true,
          style: TextStyle(color: AppPalette.textPrimary),
          decoration: InputDecoration(
            hintText: 'Nhập tên bộ thẻ...',
            hintStyle: TextStyle(color: AppPalette.textPrimary.withValues(alpha: 0.4)),
            filled: true,
            fillColor: AppPalette.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Hủy',
              style: TextStyle(color: AppPalette.textPrimary.withValues(alpha: 0.6)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppPalette.accent,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              final title = titleController.text.trim();
              if (title.isNotEmpty) {
                Navigator.pop(ctx);
                setState(() => _isLoading = true);
                try {
                  await _service.createSet(title: title);
                  await _loadDecks(query: _searchController.text);
                } catch (e) {
                  if (mounted) {
                    AppToast.showError('Không thể tạo bộ thẻ: $e', context: context);
                    setState(() => _isLoading = false);
                  }
                }
              }
            },
            child: Text(
              'Tạo',
              style: TextStyle(
                color: AppPalette.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Banner "Cần ôn hôm nay": bấm để ôn các thẻ đã tới hạn của mọi bộ.
  Widget _buildDueBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Material(
        color: AppPalette.accent,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SrsStudyScreen()),
            );
            if (mounted) _loadDueCount();
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cần ôn hôm nay',
                        style: TextStyle(
                          color: AppPalette.textPrimary.withValues(alpha: 0.85),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$_dueCount thẻ',
                        style: TextStyle(
                          color: AppPalette.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppPalette.textPrimary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    color: AppPalette.accent,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!AuthSession.instance.isAuthenticated) {
      return _buildAuthenticationRequired();
    }

    return Scaffold(
      backgroundColor: AppPalette.background,
      body: SafeArea(
        child: Column(
          children: [
            // Tiêu đề căn giữa
            // Cùng cỡ chữ và chiều cao thanh với tiêu đề "Tin nhắn" (AppBar) để hai tab đồng nhất.
            SizedBox(
              height: kToolbarHeight,
              child: Center(
                child: Text(
                  'Thư viện thẻ',
                  style: TextStyle(
                    color: AppPalette.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),

            // Ô tìm kiếm + nút "+" tạo bộ thẻ mới
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppPalette.surface,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: TextStyle(color: AppPalette.textPrimary, fontSize: 15),
                        onChanged: (val) => _loadDecks(query: val),
                        decoration: InputDecoration(
                          hintText: 'Tìm bộ từ vựng...',
                          hintStyle: TextStyle(
                            color: AppPalette.textPrimary.withValues(alpha: 0.35),
                            fontSize: 15,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: AppPalette.textPrimary.withValues(alpha: 0.4),
                            size: 22,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SquareAddButton(
                    key: const ValueKey('create-deck-button'),
                    tooltip: 'Tạo bộ thẻ mới',
                    onPressed: _openCreateDeck,
                  ),
                ],
              ),
            ),
            if (_dueCount > 0) _buildDueBanner(),
            const SizedBox(height: 8),

            // Danh sách bộ thẻ
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: AppPalette.accent,
                      ),
                    )
                  : RefreshIndicator(
                      color: AppPalette.accent,
                      backgroundColor: AppPalette.surface,
                      onRefresh: () => _loadDecks(
                        query: _searchController.text,
                        forceRefresh: true,
                      ),
                      child: _decks.isEmpty
                          ? LayoutBuilder(
                              builder: (context, constraints) => SingleChildScrollView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minHeight: constraints.maxHeight,
                                  ),
                                  child: Center(
                                    child: Text(
                                      _searchController.text.trim().isNotEmpty
                                          ? 'Không tìm thấy bộ thẻ nào'
                                          : 'Chưa có bộ thẻ nào',
                                      key: const ValueKey('no-deck-found'),
                                      style: TextStyle(
                                        color: AppPalette.textPrimary.withValues(alpha: 0.5),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(20, 12, 20, 90),
                              itemCount: _decks.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 14),
                              itemBuilder: (context, index) {
                                final deck = _decks[index];
                                return DeckCardItem(
                                  deck: deck,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            DeckOverviewScreen(deck: deck),
                                      ),
                                    );
                                  },
                                  onEdit: () => _openDeckEditor(deck),
                                  onDelete: () => _showDeleteDeckConfirmDialog(deck),
                                );
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthenticationRequired() {
    return Scaffold(
      backgroundColor: AppPalette.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                color: AppPalette.textSecondary,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'Đăng nhập để sử dụng Flashcard',
                style: TextStyle(
                  color: AppPalette.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Bộ thẻ và tiến trình học của bạn chỉ hiển thị sau khi đăng nhập.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppPalette.textSecondary),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () async {
                  await requireAuthentication(context);
                },
                child: const Text('Đăng nhập ngay'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
