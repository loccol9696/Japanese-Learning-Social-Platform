import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/services/tts_service.dart';
import '../../data/models/flashcard_item_model.dart';
import '../../data/models/flashcard_set_model.dart';
import '../../data/services/flashcard_service.dart';
import '../widgets/learning_header.dart';
import '../widgets/simple_empty_state.dart';
import '../widgets/study_options_bottom_sheet.dart';
import '../../../../core/theme/app_palette.dart';

class FlashcardFlipScreen extends StatefulWidget {
  final FlashcardSetModel deck;

  const FlashcardFlipScreen({super.key, required this.deck});

  @override
  State<FlashcardFlipScreen> createState() => _FlashcardFlipScreenState();
}

class _FlashcardFlipScreenState extends State<FlashcardFlipScreen>
    with TickerProviderStateMixin {
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
  bool _isPlayingAudio = false;
  Timer? _audioTimeoutTimer;
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
    _flipAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_flipController);

    _swipeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    )..addListener(() {
        setState(() {});
      });

    _loadCards();
  }

  @override
  void dispose() {
    _stopAudio();
    _flipController.dispose();
    _swipeController.dispose();
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

  Future<void> _loadCards() async {
    setState(() => _isLoading = true);
    final cards = await _service.getCardsInSet(
      widget.deck.setId,
      starredOnly: _options.starredOnly,
      shuffle: _options.shuffle,
    );
    if (mounted) {
      setState(() {
        _cards = cards;
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
    _stopAudio();
    _service.submitAnswer(_cards[_currentIndex].cardId, mastered);

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
      _showCompletionDialog();
    }
  }

  static const double _swipeThreshold = 140.0; // Ngưỡng kéo để kích hoạt đổi thẻ (pixel)

  void _onPanStart(DragStartDetails details) {
    if (_isAnimatingSwipe || _cards.isEmpty) return;
    _stopAudio();
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
    if (!_isDragging || (_dragOffset.dx.abs() < 8 && _dragOffset.dy.abs() < 8)) {
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
    final startAngle = (_dragOffset.dx / 300.0).clamp(-1.0, 1.0) * (15.0 * pi / 180.0);

    _isAnimatingSwipe = true;

    _dragOffsetAnimation = Tween<Offset>(
      begin: startOffset,
      end: Offset(endX, endY),
    ).animate(CurvedAnimation(
      parent: _swipeController,
      curve: Curves.easeOutCubic,
    ));

    _rotationAnimation = Tween<double>(
      begin: startAngle,
      end: endAngle,
    ).animate(CurvedAnimation(
      parent: _swipeController,
      curve: Curves.easeOutCubic,
    ));

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
    final startAngle = (_dragOffset.dx / 300.0).clamp(-1.0, 1.0) * (15.0 * pi / 180.0);

    _isAnimatingSwipe = true;

    _dragOffsetAnimation = Tween<Offset>(
      begin: startOffset,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _swipeController,
      curve: Curves.easeOutBack, // Hiệu ứng lò xo bật về vị trí trung tâm mượt mà
    ));

    _rotationAnimation = Tween<double>(
      begin: startAngle,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _swipeController,
      curve: Curves.easeOutBack,
    ));

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
    _stopAudio();
    _dragOffset = Offset(mastered ? 60 : -60, 0);
    _animateSwipe(isRight: mastered);
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppPalette.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hoàn thành xuất sắc!', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Bạn đã hoàn thành lượt ôn tập cho bộ từ vựng này.',
          style: TextStyle(color: AppPalette.textSecondary),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppPalette.accent),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Trở về', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _toggleStar() {
    if (_cards.isEmpty) return;
    final card = _cards[_currentIndex];
    final newStarred = !card.isStarred;
    _service.updateStar(card.cardId, newStarred);
    setState(() {
      _cards[_currentIndex] = card.copyWith(isStarred: newStarred);
    });
  }

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StudyOptionsBottomSheet(
        options: _options,
        onOptionsChanged: (newOptions) {
          setState(() => _options = newOptions);
          _loadCards();
        },
        onResetProgress: () async {
          await _service.resetProgress(widget.deck.setId);
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
    final swipeProgress = (currentOffset.dx.abs() / _swipeThreshold).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: AppPalette.background,
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
                  ? const Center(child: CircularProgressIndicator(color: AppPalette.accent))
                  : currentCard == null
                      ? SimpleEmptyState(
                          message: _options.starredOnly
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
                                child: _buildUnderneathCard(nextCard, swipeProgress),
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
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () => _handleManualChoice(false),
                        child: const Text('Chưa nhớ', style: TextStyle(color: AppPalette.textSecondary)),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppPalette.accent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () => _handleManualChoice(true),
                        child: const Text('Đã nhớ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
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
              child: _buildCardFront(
                nextCard,
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
        ? const Color(0xFF34D399)
        : isSwipingLeft
            ? const Color(0xFFF87171)
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
                                  color: glowColor.withValues(alpha: 0.3 * badgeOpacity),
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
                              _buildCardFront(
                                card,
                                glowColor: glowColor,
                                glowOpacity: badgeOpacity,
                              ),

                            // 2. Mặt sau (Back Face): xoay sẵn 180 độ (rotateY(180deg)), đè khít lên mặt trước
                            // và backface-visibility: hidden khi góc quay <= 90°
                            if (!isFrontVisible)
                              Transform(
                                transform: Matrix4.identity()..rotateY(pi),
                                alignment: Alignment.center,
                                child: _buildCardBack(
                                  card,
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

                // Nhãn "ĐÃ THUỘC" (Góc trên bên trái khi kéo sang phải)
                if (isSwipingRight)
                  Positioned(
                    top: 22,
                    left: 22,
                    child: Opacity(
                      opacity: badgeOpacity,
                      child: Transform.rotate(
                        angle: -15 * pi / 180,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F261C).withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFF34D399),
                              width: 2.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF34D399).withValues(alpha: 0.4),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                          child: const Text(
                            'ĐÃ THUỘC',
                            style: TextStyle(
                              color: Color(0xFF34D399),
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // Nhãn "CHƯA NHỚ" (Góc trên bên phải khi kéo sang trái)
                if (isSwipingLeft)
                  Positioned(
                    top: 22,
                    right: 22,
                    child: Opacity(
                      opacity: badgeOpacity,
                      child: Transform.rotate(
                        angle: 15 * pi / 180,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2B1216).withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFFF87171),
                              width: 2.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFF87171).withValues(alpha: 0.4),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                          child: const Text(
                            'CHƯA NHỚ',
                            style: TextStyle(
                              color: Color(0xFFF87171),
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handlePlayAudio() {
    if (_cards.isEmpty || _currentIndex >= _cards.length) return;
    final currentCard = _cards[_currentIndex];

    _audioTimeoutTimer?.cancel();

    final String textToSpeak;
    final String lang;
    final double rate;

    if (_isFront) {
      if (_options.displayFrontFace == 'term') {
        textToSpeak = currentCard.term;
        lang = 'ja-JP';
        rate = 0.9;
      } else {
        textToSpeak = currentCard.meaning;
        lang = 'vi-VN';
        rate = 1.0;
      }
    } else {
      if (_options.displayFrontFace == 'term') {
        textToSpeak = currentCard.meaning;
        lang = 'vi-VN';
        rate = 1.0;
      } else {
        textToSpeak = currentCard.term;
        lang = 'ja-JP';
        rate = 0.9;
      }
    }

    if (textToSpeak.trim().isEmpty) return;

    setState(() => _isPlayingAudio = true);

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
      top: 16,
      left: 16,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handlePlayAudio,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _isPlayingAudio
                ? AppPalette.accent.withValues(alpha: 0.18)
                : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: _isPlayingAudio
                  ? AppPalette.accent.withValues(alpha: 0.5)
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
                  ? AppPalette.accent
                  : Colors.white.withValues(alpha: 0.6),
              size: 26,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardFront(
    FlashcardItemModel card, {
    Color? glowColor,
    double glowOpacity = 0.0,
    double contentOpacity = 1.0,
  }) {
    final displayText = _options.displayFrontFace == 'term' ? card.term : card.meaning;
    final defaultBorder = AppPalette.border;
    final borderColor = glowColor != null
        ? Color.lerp(defaultBorder, glowColor, glowOpacity.clamp(0.0, 1.0))!
        : defaultBorder;

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: AppPalette.surface, // Nền đặc Solid color #1E1F28 khử trong suốt
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: borderColor,
          width: glowColor != null && glowOpacity > 0.15 ? 2.0 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Opacity(
        opacity: contentOpacity,
        child: Stack(
          children: [
            // Audio & Star icons
            _buildAudioButton(),
            Positioned(
              top: 20,
              right: 20,
              child: IconButton(
                icon: Icon(
                  card.isStarred ? Icons.star : Icons.star_border,
                  color: card.isStarred ? const Color(0xFFFFCC00) : Colors.white.withValues(alpha: 0.4),
                  size: 26,
                ),
                onPressed: _toggleStar,
              ),
            ),
            // Word
            Center(
              child: Padding(
                padding: const EdgeInsets.all(28.0),
                child: Text(
                  displayText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: _options.displayFrontFace == 'term' ? 44 : 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardBack(
    FlashcardItemModel card, {
    Color? glowColor,
    double glowOpacity = 0.0,
  }) {
    final isFrontTerm = _options.displayFrontFace == 'term';
    final defaultBorder = AppPalette.border;
    final borderColor = glowColor != null
        ? Color.lerp(defaultBorder, glowColor, glowOpacity.clamp(0.0, 1.0))!
        : defaultBorder;

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: AppPalette.surface, // Nền đặc Solid color #1E1F28 khử trong suốt
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: borderColor,
          width: glowColor != null && glowOpacity > 0.15 ? 2.0 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          _buildAudioButton(),
          Positioned(
            top: 20,
            right: 20,
            child: IconButton(
              icon: Icon(
                card.isStarred ? Icons.star : Icons.star_border,
                color: card.isStarred ? const Color(0xFFFFCC00) : Colors.white.withValues(alpha: 0.4),
                size: 26,
              ),
              onPressed: _toggleStar,
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isFrontTerm) ...[
                    // Mặt trước hiển thị định nghĩa -> Mặt sau hiển thị to rõ thuật ngữ (term)
                    Text(
                      card.term,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 42,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (card.sinoVietnamese != null && card.sinoVietnamese!.isNotEmpty)
                    Text(
                      card.sinoVietnamese!,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  if (isFrontTerm) ...[
                    const SizedBox(height: 12),
                    Text(
                      card.meaning,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700),
                    ),
                  ],
                  if (card.example != null && card.example!.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Divider(color: Colors.white.withValues(alpha: 0.1)),
                    const SizedBox(height: 12),
                    Text(
                      card.example!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14, fontStyle: FontStyle.italic),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
