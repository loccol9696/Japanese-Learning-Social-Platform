import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/services/tts_service.dart';
import '../../../../core/storage/token_storage.dart';
import '../../data/models/flashcard_item_model.dart';
import '../../data/models/flashcard_set_model.dart';
import '../../data/services/flashcard_store.dart';
import 'deck_editor_screen.dart';
import 'flashcard_flip_screen.dart';
import 'flashcard_listening_screen.dart';
import 'flashcard_matching_screen.dart';
import 'flashcard_quiz_screen.dart';
import 'flashcard_typing_screen.dart';
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
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: const BoxDecoration(
          color: Color(0xFF1E1F28),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Thanh kéo drag handle
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Dòng 1: Chỉnh sửa bộ thẻ
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: Colors.white, size: 22),
                title: const Text(
                  'Chỉnh sửa bộ thẻ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onTap: () async {
                  Navigator.pop(ctx);
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
              ),

              const SizedBox(height: 4),

              // Dòng 2: Xóa bộ thẻ
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 22),
                title: const Text(
                  'Xóa bộ thẻ',
                  style: TextStyle(
                    color: Color(0xFFEF4444),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDeleteDeck();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteDeck() {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1F28),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Xóa bộ thẻ vĩnh viễn?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Text(
          'Bạn có chắc chắn muốn xóa bộ thẻ "${widget.deck.title}"? Hành động này không thể hoàn tác.',
          style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Hủy', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () {
              Navigator.pop(dialogCtx);
              _store.optimisticDeleteSet(
                widget.deck.setId,
                onError: (err) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Không thể xóa bộ thẻ: $err'),
                        backgroundColor: const Color(0xFFFF5A5F),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Đã xóa bộ thẻ thành công'),
                  backgroundColor: Color(0xFF252632),
                  behavior: SnackBarBehavior.floating,
                ),
              );
              Navigator.pop(context, true);
            },
            child: const Text('Xóa vĩnh viễn', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
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

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã đặt lại tiến trình thẻ thành công'),
        backgroundColor: Color(0xFF252632),
        behavior: SnackBarBehavior.floating,
      ),
    );

    // Gửi request API ngầm, rollback nếu lỗi
    _store.optimisticResetProgress(
      setId: widget.deck.setId,
      onError: (err) {
        if (mounted) {
          setState(() {
            _allCards = previousAllCards;
            _applyOptions();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Không thể đặt lại tiến trình: $err'),
              backgroundColor: const Color(0xFFFF5A5F),
              behavior: SnackBarBehavior.floating,
            ),
          );
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Không thể cập nhật gắn sao: $err'),
              backgroundColor: const Color(0xFFFF5A5F),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
    );
  }

  Widget _buildModeTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161922),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: Colors.white.withOpacity(0.35),
                  size: 20,
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
    return Scaffold(
      backgroundColor: const Color(0xFF0C0E14),
      body: SafeArea(
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: RefreshIndicator(
            color: const Color(0xFFFF2D55),
            backgroundColor: const Color(0xFF1E1F28),
            onRefresh: () => _loadCards(forceRefresh: true),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              padding: const EdgeInsets.only(bottom: 36),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.settings_outlined, color: Colors.white, size: 23),
                            onPressed: _openStudyOptions,
                            splashRadius: 22,
                          ),
                          if (_isAuthor)
                            IconButton(
                              icon: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 23),
                              onPressed: _openDeckActionsSheet,
                              splashRadius: 22,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Interactive Flashcard Carousel
                Container(
                  height: 230,
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: Color(0xFFFF2D55)),
                        )
                      : _cards.isEmpty
                          ? Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF161924),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: Colors.white.withOpacity(0.08)),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                _options.starredOnly
                                    ? 'Không có từ vựng nào được gắn sao'
                                    : 'Chưa có từ vựng trong bộ thẻ',
                                style: const TextStyle(color: Colors.white54, fontSize: 15),
                              ),
                            )
                          : PageView.builder(
                              controller: _pageController,
                              itemCount: _cards.length,
                              onPageChanged: (idx) => setState(() => _currentPage = idx),
                              itemBuilder: (context, index) {
                                return _PreviewFlashcard(
                                  card: _cards[index],
                                  displayFrontFace: _options.displayFrontFace,
                                  onToggleStar: () => _toggleStar(index),
                                );
                              },
                            ),
                ),

                // Next / Back Navigation Controls
                if (_cards.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 6, 24, 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Nút Thẻ trước (Back)
                        IconButton(
                          icon: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 18,
                            color: _currentPage > 0
                                ? Colors.white
                                : Colors.white.withOpacity(0.2),
                          ),
                          onPressed: _currentPage > 0
                              ? () {
                                  _pageController.previousPage(
                                    duration: const Duration(milliseconds: 280),
                                    curve: Curves.easeOut,
                                  );
                                }
                              : null,
                          splashRadius: 22,
                        ),

                        // Chỉ số thẻ hiện tại (VD: 1 / 5)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF161822),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.06)),
                          ),
                          child: Text(
                            '${_currentPage + 1} / ${_cards.length}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),

                        // Nút Thẻ kế tiếp (Next)
                        IconButton(
                          icon: Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 18,
                            color: _currentPage < _cards.length - 1
                                ? Colors.white
                                : Colors.white.withOpacity(0.2),
                          ),
                          onPressed: _currentPage < _cards.length - 1
                              ? () {
                                  _pageController.nextPage(
                                    duration: const Duration(milliseconds: 280),
                                    curve: Curves.easeOut,
                                  );
                                }
                              : null,
                          splashRadius: 22,
                        ),
                      ],
                    ),
                  ),

                // Title & Card Count
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.deck.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${widget.deck.totalCards > 0 ? widget.deck.totalCards : _cards.length} thuật ngữ',
                        style: const TextStyle(
                          color: Color(0xFF8E8E93),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Mode Selection Tiles (Tự động mở rộng chiều cao tự nhiên, không cuộn lồng nhau)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      _buildModeTile(
                        icon: Icons.style_outlined,
                        iconColor: const Color(0xFF4A90E2),
                        iconBgColor: const Color(0xFF1E2840),
                        title: 'Thẻ ghi nhớ',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FlashcardFlipScreen(deck: widget.deck),
                            ),
                          );
                        },
                      ),
                      _buildModeTile(
                        icon: Icons.sync_alt,
                        iconColor: const Color(0xFF00C7B1),
                        iconBgColor: const Color(0xFF143034),
                        title: 'Trắc nghiệm',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FlashcardQuizScreen(
                                deck: widget.deck,
                                options: _options,
                              ),
                            ),
                          );
                        },
                      ),
                      _buildModeTile(
                        icon: Icons.edit_note,
                        iconColor: const Color(0xFF5E81F4),
                        iconBgColor: const Color(0xFF1D2444),
                        title: 'Tự luận',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FlashcardTypingScreen(
                                deck: widget.deck,
                                options: _options,
                              ),
                            ),
                          );
                        },
                      ),
                      _buildModeTile(
                        icon: Icons.headphones_rounded,
                        iconColor: const Color(0xFFFF9500),
                        iconBgColor: const Color(0xFF332314),
                        title: 'Luyện nghe',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FlashcardListeningScreen(
                                deck: widget.deck,
                                options: _options,
                              ),
                            ),
                          );
                        },
                      ),
                      _buildModeTile(
                        icon: Icons.layers_outlined,
                        iconColor: const Color(0xFF8B6BF6),
                        iconBgColor: const Color(0xFF282148),
                        title: 'Ghép thẻ',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FlashcardMatchingScreen(deck: widget.deck),
                            ),
                          );
                        },
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
}

class _PreviewFlashcard extends StatefulWidget {
  final FlashcardItemModel card;
  final String frontLanguage; // Giữ lại trường cũ để Hot Reload không báo Const class cannot remove fields
  final String displayFrontFace; // 'term' or 'definition'
  final VoidCallback onToggleStar;

  const _PreviewFlashcard({
    required this.card,
    this.frontLanguage = 'ja',
    this.displayFrontFace = 'term',
    required this.onToggleStar,
  });

  String get effectiveFrontFace =>
      displayFrontFace != 'term' ? displayFrontFace : (frontLanguage == 'vi' ? 'definition' : 'term');

  @override
  State<_PreviewFlashcard> createState() => _PreviewFlashcardState();
}

class _PreviewFlashcardState extends State<_PreviewFlashcard>
  with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isFront = true;
  bool _isPlayingAudio = false;
  Timer? _audioTimeoutTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(covariant _PreviewFlashcard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.card.cardId != widget.card.cardId) {
      _controller.reset();
      _isFront = true;
      _stopAudio();
    }
  }

  @override
  void dispose() {
    _stopAudio();
    _controller.dispose();
    super.dispose();
  }

  void _stopAudio() {
    _audioTimeoutTimer?.cancel();
    _audioTimeoutTimer = null;
    TtsService.stop();
    if (_isPlayingAudio && mounted) {
      setState(() => _isPlayingAudio = false);
    }
  }

  void _flip() {
    if (_isFront) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    setState(() => _isFront = !_isFront);
  }

  void _handlePlayAudio() {
    _audioTimeoutTimer?.cancel();

    final String textToSpeak;
    final String lang;
    final double rate;
    final frontFace = widget.effectiveFrontFace;

    if (_isFront) {
      if (frontFace == 'term') {
        textToSpeak = widget.card.term;
        lang = 'ja-JP';
        rate = 0.9;
      } else {
        textToSpeak = widget.card.meaning;
        lang = 'vi-VN';
        rate = 1.0;
      }
    } else {
      // Khi đang xem mặt sau:
      if (frontFace == 'term') {
        textToSpeak = widget.card.meaning;
        lang = 'vi-VN';
        rate = 1.0;
      } else {
        textToSpeak = widget.card.term;
        lang = 'ja-JP';
        rate = 0.9;
      }
    }

    if (textToSpeak.trim().isEmpty) return;

    setState(() => _isPlayingAudio = true);

    // Fallback timer đề phòng sự kiện onend của Web Speech API bị trễ
    _audioTimeoutTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _isPlayingAudio) {
        setState(() => _isPlayingAudio = false);
      }
    });

    TtsService.speak(
      text: textToSpeak,
      lang: lang,
      rate: rate,
      onStart: () {
        if (mounted && !_isPlayingAudio) {
          setState(() => _isPlayingAudio = true);
        }
      },
      onComplete: () {
        _audioTimeoutTimer?.cancel();
        if (mounted) {
          setState(() => _isPlayingAudio = false);
        }
      },
    );
  }

  Widget _buildAudioButton() {
    return Positioned(
      top: 4,
      left: 4,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handlePlayAudio,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _isPlayingAudio
                ? const Color(0xFFFF5A5F).withValues(alpha: 0.18)
                : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: _isPlayingAudio
                  ? const Color(0xFFFF5A5F).withValues(alpha: 0.5)
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: AnimatedScale(
            scale: _isPlayingAudio ? 1.2 : 1.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutBack,
            child: Icon(
              _isPlayingAudio ? Icons.volume_up_rounded : Icons.volume_up_outlined,
              color: _isPlayingAudio
                  ? const Color(0xFFFF5A5F)
                  : Colors.white.withValues(alpha: 0.5),
              size: 22,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _flip,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final angle = _animation.value * pi;
          final isFrontVisible = angle <= (pi / 2);

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001) // 3D perspective
              ..rotateY(angle),
            child: isFrontVisible
                ? _buildFront()
                : Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(pi),
                    child: _buildBack(),
                  ),
          );
        },
      ),
    );
  }

  Widget _buildFront() {
    final frontFace = widget.effectiveFrontFace;
    final displayText = frontFace == 'term' ? widget.card.term : widget.card.meaning;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1F28), // Nền đặc Solid color #1E1F28 khử trong suốt
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF323344), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Audio icon
          _buildAudioButton(),
          // Star icon
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              icon: Icon(
                widget.card.isStarred ? Icons.star_rounded : Icons.star_outline_rounded,
                color: widget.card.isStarred ? const Color(0xFFFFCC00) : Colors.white.withValues(alpha: 0.4),
                size: 24,
              ),
              onPressed: widget.onToggleStar,
              splashRadius: 20,
            ),
          ),
          // Center Text
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: frontFace == 'term' ? 40 : 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBack() {
    final frontFace = widget.effectiveFrontFace;
    final backText = frontFace == 'term' ? widget.card.meaning : widget.card.term;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1F28), // Nền đặc Solid color #1E1F28 khử trong suốt
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF323344), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Audio icon
          _buildAudioButton(),
          // Star icon
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              icon: Icon(
                widget.card.isStarred ? Icons.star_rounded : Icons.star_outline_rounded,
                color: widget.card.isStarred ? const Color(0xFFFFCC00) : Colors.white.withValues(alpha: 0.4),
                size: 24,
              ),
              onPressed: widget.onToggleStar,
              splashRadius: 20,
            ),
          ),
          // Center Text & Reading
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.card.reading != null && widget.card.reading!.isNotEmpty) ...[
                  Text(
                    widget.card.reading!,
                    style: const TextStyle(
                      color: Color(0xFFFF5E7E),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                Text(
                  backText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: frontFace == 'term' ? 24 : 38,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
}
