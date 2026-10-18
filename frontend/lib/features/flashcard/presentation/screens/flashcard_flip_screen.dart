import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/flashcard_item_model.dart';
import '../../data/models/flashcard_set_model.dart';
import '../../data/services/flashcard_service.dart';
import '../widgets/card_audio.dart';
import '../widgets/flip_card_widgets.dart';
import '../widgets/learning_header.dart';
import '../widgets/simple_empty_state.dart';
import '../widgets/study_options_bottom_sheet.dart';

class FlashcardFlipScreen extends StatefulWidget {
  final FlashcardSetModel deck;

  const FlashcardFlipScreen({super.key, required this.deck});

  @override
  State<FlashcardFlipScreen> createState() => _FlashcardFlipScreenState();
}

class _FlashcardFlipScreenState extends State<FlashcardFlipScreen>
    with TickerProviderStateMixin, CardAudioMixin {
  final FlashcardService _service = FlashcardService.instance;
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  late AnimationController _swipeController;
  Animation<Offset>? _dragOffsetAnimation;
  Animation<double>? _rotationAnimation;

  List<FlashcardItemModel> _cards = [];
  int _currentIndex = 0;
  bool _isFront = true;
  bool _isLoading = true;
  String? _loadError;
  StudyOptions _options = StudyOptions();

  Offset _dragOffset = Offset.zero;
  bool _isDragging = false;
  bool _isAnimatingSwipe = false;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _flipAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_flipController);

    _swipeController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 240),
        )..addListener(() {
          setState(() {});
        });

    _loadCards();
  }

  @override
  void dispose() {
    _flipController.dispose();
    _swipeController.dispose();
    super.dispose();
  }

  Future<void> _loadCards() async {
    setState(() => _isLoading = true);
    final List<FlashcardItemModel> cards;
    try {
      cards = await _service.getCardsInSet(
        widget.deck.setId,
        starredOnly: _options.starredOnly,
        shuffle: _options.shuffle,
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _cards = [];
          _loadError = 'Không tải được bộ thẻ. Vui lòng thử lại.';
          _isLoading = false;
        });
      }
      return;
    }
    if (mounted) {
      setState(() {
        _cards = cards;
        _loadError = null;
        _currentIndex = 0;
        _isFront = true;
        _flipController.reset();
        _dragOffset = Offset.zero;
        _isDragging = false;
        _isAnimatingSwipe = false;
        _isLoading = false;
      });
    }
  }

  void _flipCard() {
    if (_isFront) {
      _flipController.forward();
    } else {
      _flipController.reverse();
    }
    setState(() => _isFront = !_isFront);
  }

  void _nextCard(bool mastered) {
    if (_cards.isEmpty) return;
    stopCardAudio();
    // Gửi ngầm; lỗi chỉ ảnh hưởng thống kê ôn tập nên không chặn luồng học.
    _service
        .submitAnswer(_cards[_currentIndex].cardId, mastered)
        .catchError(
          (Object e) => debugPrint('Không gửi được kết quả ôn tập: $e'),
        );

    if (_currentIndex < _cards.length - 1) {
      setState(() {
        _currentIndex++;
        _isFront = true;
        _flipController.reset();
        _dragOffset = Offset.zero;
        _isDragging = false;
        _isAnimatingSwipe = false;
      });
    } else {
      showFlipCompleteDialog(context);
    }
  }

  static const double _swipeThreshold =
      140.0; // Ngưỡng kéo để kích hoạt đổi thẻ (pixel)

  void _onPanStart(DragStartDetails details) {
    if (_isAnimatingSwipe || _cards.isEmpty) return;
    stopCardAudio();
    _isDragging = false;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_isAnimatingSwipe || _cards.isEmpty) return;
    setState(() {
      _dragOffset += details.delta;
      if (_dragOffset.dx.abs() > 6 || _dragOffset.dy.abs() > 6) {
        _isDragging = true;
      }
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_isAnimatingSwipe || _cards.isEmpty) return;

    // 1. Nếu chỉ nhấp tay (tap) hoặc di chuyển cực nhỏ (< 8px), coi như lật mặt thẻ
    if (!_isDragging ||
        (_dragOffset.dx.abs() < 8 && _dragOffset.dy.abs() < 8)) {
      _flipCard();
      setState(() {
        _dragOffset = Offset.zero;
        _isDragging = false;
      });
      return;
    }

    final vx = details.velocity.pixelsPerSecond.dx;
    // Kết hợp gia tốc: chỉ tính cú vuốt nhanh khi vận tốc lớn (> 800) VÀ đã kéo một khoảng tối thiểu (> 50px)
    final isQuickFlickRight = vx > 800 && _dragOffset.dx > 50;
    final isQuickFlickLeft = vx < -800 && _dragOffset.dx < -50;

    // 2. Kiểm tra ngưỡng kéo (SWIPE_THRESHOLD)
    if (_dragOffset.dx > _swipeThreshold || isQuickFlickRight) {
      // Xác nhận vuốt phải (Đã thuộc) -> Thẻ bay mất hút về bên phải và chuyển thẻ kế
      _animateSwipe(isRight: true);
    } else if (_dragOffset.dx < -_swipeThreshold || isQuickFlickLeft) {
      // Xác nhận vuốt trái (Chưa nhớ) -> Thẻ bay mất hút về bên trái và chuyển thẻ kế
      _animateSwipe(isRight: false);
    } else {
      // TRƯỜNG HỢP QUAN TRỌNG: Vuốt chưa đủ lực (-SWIPE_THRESHOLD <= dragX <= SWIPE_THRESHOLD)
      // Thẻ tự động nảy về (spring / snap back) vị trí trung tâm ban đầu, không đổi thẻ!
      _animateBounceBack();
    }
  }

  void _animateSwipe({required bool isRight}) {
    if (_cards.isEmpty || _isAnimatingSwipe) return;
    final screenWidth = MediaQuery.of(context).size.width;
    final endX = isRight ? screenWidth + 300.0 : -screenWidth - 300.0;
    final endY = _dragOffset.dy * 1.5;
    final endAngle = isRight ? (22.0 * pi / 180.0) : (-22.0 * pi / 180.0);

    final startOffset = _dragOffset;
    final startAngle =
        (_dragOffset.dx / 300.0).clamp(-1.0, 1.0) * (15.0 * pi / 180.0);

    _isAnimatingSwipe = true;

    _dragOffsetAnimation =
        Tween<Offset>(begin: startOffset, end: Offset(endX, endY)).animate(
          CurvedAnimation(parent: _swipeController, curve: Curves.easeOutCubic),
        );

    _rotationAnimation = Tween<double>(begin: startAngle, end: endAngle)
        .animate(
          CurvedAnimation(parent: _swipeController, curve: Curves.easeOutCubic),
        );

    _swipeController.forward(from: 0.0).then((_) {
      _nextCard(isRight);
      if (mounted) {
        setState(() {
          _dragOffset = Offset.zero;
          _isDragging = false;
          _isAnimatingSwipe = false;
        });
        _swipeController.reset();
      }
    });
  }

  void _animateBounceBack() {
    final startOffset = _dragOffset;
    final startAngle =
        (_dragOffset.dx / 300.0).clamp(-1.0, 1.0) * (15.0 * pi / 180.0);

    _isAnimatingSwipe = true;

    _dragOffsetAnimation = Tween<Offset>(begin: startOffset, end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _swipeController,
            curve: Curves
                .easeOutBack, // Hiệu ứng lò xo bật về vị trí trung tâm mượt mà
          ),
        );

    _rotationAnimation = Tween<double>(begin: startAngle, end: 0.0).animate(
      CurvedAnimation(parent: _swipeController, curve: Curves.easeOutBack),
    );

    _swipeController.forward(from: 0.0).then((_) {
      if (mounted) {
        setState(() {
          _dragOffset = Offset.zero;
          _isDragging = false;
          _isAnimatingSwipe = false;
        });
        _swipeController.reset();
      }
    });
  }

  void _handleManualChoice(bool mastered) {
    if (_isAnimatingSwipe || _cards.isEmpty) return;
    stopCardAudio();
    _dragOffset = Offset(mastered ? 60 : -60, 0);
    _animateSwipe(isRight: mastered);
  }

  void _toggleStar() {
    if (_cards.isEmpty) return;
    final card = _cards[_currentIndex];
    final newStarred = !card.isStarred;

    void setStarred(bool starred) {
      final index = _cards.indexWhere((c) => c.cardId == card.cardId);
      if (index != -1) _cards[index] = card.copyWith(isStarred: starred);
    }

    // Optimistic update, hoàn tác nếu API lỗi.
    setState(() => setStarred(newStarred));
    _service.updateStar(card.cardId, newStarred).catchError((Object e) {
      if (!mounted) return;
      setState(() => setStarred(!newStarred));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không thể cập nhật gắn sao: $e')));
    });
  }

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StudyOptionsBottomSheet(
        options: _options,
        onOptionsChanged: (newOptions) {
          setState(() => _options = newOptions);
          _loadCards();
        },
        onResetProgress: () async {
          try {
            await _service.resetProgress(widget.deck.setId);
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Không thể đặt lại tiến trình: $e')),
              );
            }
            return;
          }
          _loadCards();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _cards.length;
    final displayIndex = total > 0 ? _currentIndex + 1 : 0;
    final currentCard = _cards.isNotEmpty ? _cards[_currentIndex] : null;
    final nextCard = (_cards.isNotEmpty && _currentIndex + 1 < _cards.length)
        ? _cards[_currentIndex + 1]
        : null;

    final currentOffset = _isAnimatingSwipe
        ? (_dragOffsetAnimation?.value ?? _dragOffset)
        : _dragOffset;
    final currentAngle = _isAnimatingSwipe
        ? (_rotationAnimation?.value ?? 0.0)
        : ((currentOffset.dx / 300.0).clamp(-1.0, 1.0) * (15.0 * pi / 180.0));
    final swipeProgress = (currentOffset.dx.abs() / _swipeThreshold).clamp(
      0.0,
      1.0,
    );

    return Scaffold(
      backgroundColor: AppColors.flashBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar & Continuous Progress Bar
            LearningHeader(
              currentIndex: displayIndex,
              totalItems: total,
              onClose: () => Navigator.pop(context),
              onSettingsClick: _openSettings,
            ),

            const SizedBox(height: 16),

            // Giant Center Flashcard Stack (Quizlet Style Swipe)
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.flashAccent,
                      ),
                    )
                  : currentCard == null
                  ? SimpleEmptyState(
                      message: _loadError != null
                          ? _loadError!
                          : _options.starredOnly
                          ? 'Không có từ vựng nào được gắn sao.'
                          : 'Không có từ vựng nào trong danh sách.',
                      onBack: () => Navigator.pop(context),
                    )
                  : Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        // Thẻ tiếp theo nằm bên dưới (z-index thấp hơn thẻ chính)
                        if (nextCard != null)
                          Positioned.fill(
                            child: _buildUnderneathCard(
                              nextCard,
                              swipeProgress,
                            ),
                          ),

                        // Thẻ chính đang tương tác vuốt kéo thả (z-index cao hơn)
                        Positioned.fill(
                          child: _buildActiveCard(
                            currentCard,
                            currentOffset,
                            currentAngle,
                            swipeProgress,
                          ),
                        ),
                      ],
                    ),
            ),

            // Bottom action hint / buttons (Đồng bộ với thao tác vuốt - chỉ hiện khi có thẻ)
            if (_cards.isNotEmpty)
              FlipChoiceButtons(
                onUnknown: () => _handleManualChoice(false),
                onKnown: () => _handleManualChoice(true),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnderneathCard(FlashcardItemModel nextCard, double progress) {
    final scale = 0.93 + (0.07 * progress);
    final opacity = (0.50 + (0.50 * progress)).clamp(0.0, 1.0);
    final translateY = 14.0 * (1.0 - progress);
    // Khi thẻ trên đang lật tại chỗ (progress == 0), thẻ dưới ẩn hoàn toàn chữ (contentOpacity = 0.0)
    // để không bao giờ bị lộ/bóng chữ đè lên thẻ trên. Chỉ hiện chữ khi vuốt thẻ (progress > 0).
    final textOpacity = (progress * 2.5).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Transform.translate(
        offset: Offset(0, translateY),
        child: Transform.scale(
          scale: scale,
          alignment: Alignment.center,
          child: Opacity(
            opacity: opacity,
            child: IgnorePointer(
              ignoring: true,
              child: _buildFace(
                nextCard,
                isBack: false,
                contentOpacity: textOpacity,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveCard(
    FlashcardItemModel card,
    Offset offset,
    double angle,
    double swipeProgress,
  ) {
    final isSwipingRight = offset.dx > 15;
    final isSwipingLeft = offset.dx < -15;
    // Opacity của badge tăng dần từ từ theo quãng đường kéo (từ 0 đến 100% tại _swipeThreshold = 140px)
    final badgeOpacity = (offset.dx.abs() / _swipeThreshold).clamp(0.0, 1.0);

    final Color? glowColor = isSwipingRight
        ? AppColors.flashKnown
        : isSwipingLeft
        ? AppColors.flashUnknown
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        child: Transform.translate(
          offset: Offset(offset.dx, offset.dy * 0.4),
          child: Transform.rotate(
            angle: angle,
            alignment: Alignment.center,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Thẻ lật 3D (Card Inner: preserve-3d, backface-visibility: hidden)
                AnimatedBuilder(
                  animation: _flipAnimation,
                  builder: (context, child) {
                    final flipAngle = _flipAnimation.value * pi;
                    // Mặt trước hiển thị khi góc <= 90 độ (pi / 2)
                    final isFrontVisible = flipAngle <= pi / 2;

                    return Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: glowColor != null
                            ? [
                                BoxShadow(
                                  color: glowColor.withValues(
                                    alpha: 0.3 * badgeOpacity,
                                  ),
                                  blurRadius: 24,
                                  spreadRadius: 2,
                                ),
                              ]
                            : null,
                      ),
                      child: Transform(
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.001) // perspective 3D
                          ..rotateY(flipAngle),
                        alignment: Alignment.center,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // 1. Mặt trước (Front Face): backface-visibility: hidden khi góc quay > 90°
                            if (isFrontVisible)
                              _buildFace(
                                card,
                                isBack: false,
                                glowColor: glowColor,
                                glowOpacity: badgeOpacity,
                              ),

                            // 2. Mặt sau (Back Face): xoay sẵn 180 độ (rotateY(180deg)), đè khít lên mặt trước
                            // và backface-visibility: hidden khi góc quay <= 90°
                            if (!isFrontVisible)
                              Transform(
                                transform: Matrix4.identity()..rotateY(pi),
                                alignment: Alignment.center,
                                child: _buildFace(
                                  card,
                                  isBack: true,
                                  glowColor: glowColor,
                                  glowOpacity: badgeOpacity,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                if (isSwipingRight)
                  SwipeVerdictBadge(known: true, opacity: badgeOpacity),
                if (isSwipingLeft)
                  SwipeVerdictBadge(known: false, opacity: badgeOpacity),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handlePlayAudio() {
    if (_cards.isEmpty || _currentIndex >= _cards.length) return;
    // Đọc mặt đang hiển thị: thuật ngữ → tiếng Nhật, nghĩa → tiếng Việt.
    playCardAudio(
      _cards[_currentIndex],
      speakTerm: _isFront == (_options.displayFrontFace == 'term'),
    );
  }

  Widget _buildFace(
    FlashcardItemModel card, {
    required bool isBack,
    Color? glowColor,
    double glowOpacity = 0.0,
    double contentOpacity = 1.0,
  }) {
    return FlipCardFace(
      card: card,
      isBack: isBack,
      displayFrontFace: _options.displayFrontFace,
      audioButton: CardAudioButton(
        isPlaying: isPlayingAudio,
        onTap: _handlePlayAudio,
        inset: 16,
        iconSize: 26,
        idleAlpha: 0.6,
      ),
      onToggleStar: _toggleStar,
      glowColor: glowColor,
      glowOpacity: glowOpacity,
      contentOpacity: contentOpacity,
    );
  }
}
