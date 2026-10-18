import 'package:flutter/material.dart';
import '../../../../core/storage/token_storage.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/flashcard_item_model.dart';
import '../../data/models/flashcard_set_model.dart';
import '../../data/services/flashcard_store.dart';
import 'deck_editor_screen.dart';
import 'flashcard_flip_screen.dart';
import 'flashcard_listening_screen.dart';
import 'flashcard_matching_screen.dart';
import 'flashcard_quiz_screen.dart';
import 'flashcard_typing_screen.dart';
import '../widgets/deck_overview_sheets.dart';
import '../widgets/deck_overview_widgets.dart';
import '../widgets/deck_preview_flashcard.dart';
import '../widgets/study_options_bottom_sheet.dart';

class DeckOverviewScreen extends StatefulWidget {
  final FlashcardSetModel deck;

  const DeckOverviewScreen({super.key, required this.deck});

  @override
  State<DeckOverviewScreen> createState() => _DeckOverviewScreenState();
}

class _DeckOverviewScreenState extends State<DeckOverviewScreen> {
  final PageController _pageController = PageController();
  final FlashcardStore _store = FlashcardStore.instance;
  int _currentPage = 0;
  List<FlashcardItemModel> _allCards = [];
  List<FlashcardItemModel> _cards = [];
  bool _isLoading = false;
  bool _isAuthor = true;
  StudyOptions _options = StudyOptions();

  @override
  void initState() {
    super.initState();
    _checkIfAuthor();
    // Cache-First (0ms): Nếu bộ thẻ này đã từng nạp, lấy ngay lập tức từ RAM/Cache
    if (_store.hasCachedCards(widget.deck.setId)) {
      _allCards = List.from(_store.getCachedCards(widget.deck.setId)!);
      _applyOptions();
      _isLoading = false;
    } else {
      _isLoading = true;
    }

    _loadCards();
  }

  /// Nạp danh sách thẻ với Stale-While-Revalidate:
  /// - Không gán _isLoading = true nếu đã có cache để tránh chớp màn hình
  /// - Tự động đồng bộ ngầm sau 5 phút hoặc khi pull-to-refresh
  Future<void> _loadCards({bool forceRefresh = false}) async {
    if (!_store.hasCachedCards(widget.deck.setId) && _allCards.isEmpty) {
      setState(() => _isLoading = true);
    }

    final cards = await _store.getCardsInSet(
      widget.deck.setId,
      forceRefresh: forceRefresh,
      onBackgroundUpdated: (freshCards) {
        if (mounted) {
          setState(() {
            _allCards = freshCards;
            _applyOptions();
            _isLoading = false;
          });
        }
      },
    );

    if (mounted) {
      setState(() {
        _allCards = cards;
        _applyOptions();
        _isLoading = false;
      });
    }
  }

  void _applyOptions() {
    List<FlashcardItemModel> list = List.from(_allCards);
    if (_options.starredOnly) {
      list = list.where((c) => c.isStarred).toList();
    }
    if (_options.shuffle) {
      list.shuffle();
    }
    _cards = list;
    if (_currentPage >= _cards.length) {
      _currentPage = _cards.isEmpty ? 0 : _cards.length - 1;
    }
  }

  Future<void> _checkIfAuthor() async {
    final userData = await TokenStorage.instance.getUserData();
    if (userData != null && mounted) {
      final currentUserId = userData['id'] is int
          ? userData['id'] as int
          : (userData['id'] != null ? int.tryParse(userData['id'].toString()) : null);
      final currentUsername = (userData['username'] as String?)?.toLowerCase();

      final deckAuthorId = widget.deck.authorId;
      final deckAuthorName = widget.deck.authorName.toLowerCase();

      final isOwner = (deckAuthorId != null && currentUserId != null && deckAuthorId == currentUserId) ||
          (currentUsername != null && deckAuthorName == currentUsername) ||
          deckAuthorId == null;

      setState(() {
        _isAuthor = isOwner;
      });
    }
  }

  void _openDeckActionsSheet() {
    showDeckActionsSheet(
      context,
      onEdit: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DeckEditorScreen(deck: widget.deck),
          ),
        );
        if (result == true) {
          _loadCards(forceRefresh: true);
        }
      },
      onDelete: _confirmDeleteDeck,
    );
  }

  void _confirmDeleteDeck() {
    showDeleteDeckDialog(
      context,
      deckTitle: widget.deck.title,
      onConfirm: () {
        _store.optimisticDeleteSet(
          widget.deck.setId,
          onError: (err) {
            if (mounted) {
              showDeckSnackBar(context, 'Không thể xóa bộ thẻ: $err',
                  isError: true);
            }
          },
        );
        showDeckSnackBar(context, 'Đã xóa bộ thẻ thành công');
        Navigator.pop(context, true);
      },
    );
  }

  void _openStudyOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StudyOptionsBottomSheet(
        options: _options,
        onOptionsChanged: (newOptions) {
          setState(() {
            _options = newOptions;
            _applyOptions();
          });
        },
        onResetProgress: _resetProgress,
      ),
    );
  }

  /// Đặt lại tiến trình học với Optimistic Update (0ms)
  Future<void> _resetProgress() async {
    final previousAllCards = List<FlashcardItemModel>.from(_allCards);

    // Cập nhật ngay tức thì 0ms trên UI
    setState(() {
      for (int i = 0; i < _allCards.length; i++) {
        _allCards[i] = _allCards[i].copyWith(
          boxLevel: 0,
          correctCount: 0,
          incorrectCount: 0,
        );
      }
      _applyOptions();
    });

    showDeckSnackBar(context, 'Đã đặt lại tiến trình thẻ thành công');

    // Gửi request API ngầm, rollback nếu lỗi
    _store.optimisticResetProgress(
      setId: widget.deck.setId,
      onError: (err) {
        if (mounted) {
          setState(() {
            _allCards = previousAllCards;
            _applyOptions();
          });
          showDeckSnackBar(context, 'Không thể đặt lại tiến trình: $err',
              isError: true);
        }
      },
    );
  }

  /// Gắn sao / Bỏ gắn sao với Optimistic Update (0ms)
  void _toggleStar(int index) {
    if (index < 0 || index >= _cards.length) return;
    final card = _cards[index];
    final newStarred = !card.isStarred;

    // 1. Cập nhật UI ngay lập tức 0ms
    setState(() {
      final updatedCard = card.copyWith(isStarred: newStarred);
      _cards[index] = updatedCard;
      final allIdx = _allCards.indexWhere((c) => c.cardId == card.cardId);
      if (allIdx != -1) {
        _allCards[allIdx] = updatedCard;
      }
      if (_options.starredOnly && !newStarred) {
        _applyOptions();
      }
    });

    // 2. Gửi API ngầm, rollback nếu xảy ra lỗi
    _store.optimisticToggleStar(
      setId: widget.deck.setId,
      cardId: card.cardId,
      newStarred: newStarred,
      onError: (err) {
        if (mounted) {
          setState(() {
            final revertedCard = card.copyWith(isStarred: !newStarred);
            final curIdx = _cards.indexWhere((c) => c.cardId == card.cardId);
            if (curIdx != -1) _cards[curIdx] = revertedCard;
            final allIdx = _allCards.indexWhere((c) => c.cardId == card.cardId);
            if (allIdx != -1) _allCards[allIdx] = revertedCard;
            _applyOptions();
          });
          showDeckSnackBar(context, 'Không thể cập nhật gắn sao: $err',
              isError: true);
        }
      },
    );
  }

  void _openMode(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
  }

  void _goToPage(bool next) {
    const duration = Duration(milliseconds: 280);
    if (next) {
      _pageController.nextPage(duration: duration, curve: Curves.easeOut);
    } else {
      _pageController.previousPage(duration: duration, curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final deck = widget.deck;

    return Scaffold(
      backgroundColor: AppColors.flashBackground,
      body: SafeArea(
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: RefreshIndicator(
            color: AppColors.flashAccent,
            backgroundColor: AppColors.socialSurface,
            onRefresh: () => _loadCards(forceRefresh: true),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              padding: const EdgeInsets.only(bottom: 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DeckOverviewTopBar(
                    onOpenOptions: _openStudyOptions,
                    onOpenActions: _isAuthor ? _openDeckActionsSheet : null,
                  ),

                  // Interactive Flashcard Carousel
                  Container(
                    height: 230,
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: _buildCarousel(),
                  ),

                  if (_cards.isNotEmpty)
                    DeckCardPager(
                      currentPage: _currentPage,
                      total: _cards.length,
                      onPrevious: () => _goToPage(false),
                      onNext: () => _goToPage(true),
                    ),

                  DeckTitleSection(
                    title: deck.title,
                    termCount: deck.totalCards > 0 ? deck.totalCards : _cards.length,
                  ),

                  const SizedBox(height: 16),

                  // Mode Selection Tiles (Tự động mở rộng chiều cao tự nhiên, không cuộn lồng nhau)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        DeckModeTile(
                          icon: Icons.style_outlined,
                          iconColor: AppColors.modeFlip,
                          iconBgColor: AppColors.modeFlipBg,
                          title: 'Thẻ ghi nhớ',
                          onTap: () => _openMode(FlashcardFlipScreen(deck: deck)),
                        ),
                        DeckModeTile(
                          icon: Icons.sync_alt,
                          iconColor: AppColors.modeQuiz,
                          iconBgColor: AppColors.modeQuizBg,
                          title: 'Trắc nghiệm',
                          onTap: () => _openMode(
                              FlashcardQuizScreen(deck: deck, options: _options)),
                        ),
                        DeckModeTile(
                          icon: Icons.edit_note,
                          iconColor: AppColors.modeTyping,
                          iconBgColor: AppColors.modeTypingBg,
                          title: 'Tự luận',
                          onTap: () => _openMode(
                              FlashcardTypingScreen(deck: deck, options: _options)),
                        ),
                        DeckModeTile(
                          icon: Icons.headphones_rounded,
                          iconColor: AppColors.modeListening,
                          iconBgColor: AppColors.modeListeningBg,
                          title: 'Luyện nghe',
                          onTap: () => _openMode(FlashcardListeningScreen(
                              deck: deck, options: _options)),
                        ),
                        DeckModeTile(
                          icon: Icons.layers_outlined,
                          iconColor: AppColors.modeMatching,
                          iconBgColor: AppColors.modeMatchingBg,
                          title: 'Ghép thẻ',
                          onTap: () => _openMode(FlashcardMatchingScreen(deck: deck)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCarousel() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.flashAccent),
      );
    }
    if (_cards.isEmpty) {
      return DeckEmptyCarousel(
        message: _options.starredOnly
            ? 'Không có từ vựng nào được gắn sao'
            : 'Chưa có từ vựng trong bộ thẻ',
      );
    }
    return PageView.builder(
      controller: _pageController,
      itemCount: _cards.length,
      onPageChanged: (idx) => setState(() => _currentPage = idx),
      itemBuilder: (context, index) {
        return DeckPreviewFlashcard(
          card: _cards[index],
          displayFrontFace: _options.displayFrontFace,
          onToggleStar: () => _toggleStar(index),
        );
      },
    );
  }
}
