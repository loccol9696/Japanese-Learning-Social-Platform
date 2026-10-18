import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/tts_service.dart';
import '../../data/models/flashcard_item_model.dart';
import '../../data/models/flashcard_set_model.dart';
import '../../data/services/flashcard_service.dart';
import '../widgets/learning_header.dart';
import '../widgets/simple_empty_state.dart';
import '../widgets/study_options_bottom_sheet.dart';

class FlashcardListeningScreen extends StatefulWidget {
  final FlashcardSetModel deck;
  final StudyOptions? options;

  const FlashcardListeningScreen({
    super.key,
    required this.deck,
    this.options,
  });

  @override
  State<FlashcardListeningScreen> createState() => _FlashcardListeningScreenState();
}

class _FlashcardListeningScreenState extends State<FlashcardListeningScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final FlashcardService _service = FlashcardService.instance;

  List<FlashcardItemModel> _cards = [];
  int _currentIndex = 0;
  bool _isLoading = true;
  String? _feedbackMessage;
  bool? _isCorrect;

  bool _isPlayingAudio = false;
  double _speechRate = 1.0; // 1.0 or 0.7
  bool _isButtonPressed = false;

  Timer? _audioTimeoutTimer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  late StudyOptions _options;

  @override
  void initState() {
    super.initState();
    _options = widget.options?.copyWith() ?? StudyOptions();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.20).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadCards();
  }

  @override
  void dispose() {
    _stopAudio();
    _pulseController.dispose();
    _inputController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadCards() async {
    setState(() => _isLoading = true);
    final list = await _service.getCardsInSet(
      widget.deck.setId,
      starredOnly: _options.starredOnly,
      shuffle: _options.shuffle,
    );
    if (mounted) {
      setState(() {
        _cards = list;
        _currentIndex = 0;
        _inputController.clear();
        _isCorrect = null;
        _feedbackMessage = null;
        _isLoading = false;
      });
      _focusNode.requestFocus();
      if (_cards.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 350), () {
          if (mounted) _playCurrentAudio();
        });
      }
    }
  }

  void _stopAudio() {
    _audioTimeoutTimer?.cancel();
    _audioTimeoutTimer = null;
    if (_pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.reset();
    }
    if (_isPlayingAudio && mounted) {
      setState(() => _isPlayingAudio = false);
    }
  }

  void _playCurrentAudio() {
    if (_cards.isEmpty || _currentIndex >= _cards.length) return;
    _stopAudio();

    final card = _cards[_currentIndex];
    final isDefinition = _options.displayFrontFace == 'definition';
    final textToSpeak = isDefinition ? card.meaning.trim() : card.term.trim();
    final langCode = isDefinition ? 'vi-VN' : 'ja-JP';

    if (textToSpeak.isEmpty) return;

    setState(() => _isPlayingAudio = true);
    _pulseController.repeat(reverse: true);

    _audioTimeoutTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) _stopAudio();
    });

    TtsService.speak(
      text: textToSpeak,
      lang: langCode,
      rate: _speechRate,
      onStart: () {
        if (mounted && !_isPlayingAudio) {
          setState(() => _isPlayingAudio = true);
          _pulseController.repeat(reverse: true);
        }
      },
      onComplete: () {
        if (mounted) _stopAudio();
      },
    );
  }

  void _toggleSpeed() {
    setState(() {
      _speechRate = (_speechRate == 1.0) ? 0.7 : 1.0;
    });
    _playCurrentAudio();
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

  void _checkAnswer() {
    if (_cards.isEmpty || _inputController.text.trim().isEmpty) return;

    final card = _cards[_currentIndex];
    final userInput = _inputController.text.trim().toLowerCase();
    final isDefinition = _options.displayFrontFace == 'definition';

    bool isMatch;
    String fullAnswerDisplay;

    if (isDefinition) {
      // Phát định nghĩa tiếng Việt -> Nhập thuật ngữ tiếng Nhật
      final correctTerm = card.term.trim().toLowerCase();
      final correctReading = (card.reading ?? '').trim().toLowerCase();
      isMatch = userInput == correctTerm ||
          (correctReading.isNotEmpty && userInput == correctReading);

      final readingPart = (card.reading != null &&
              card.reading!.trim().isNotEmpty &&
              card.reading!.trim().toLowerCase() != card.term.trim().toLowerCase())
          ? ' (${card.reading})'
          : '';
      fullAnswerDisplay = '${card.term}$readingPart: ${card.meaning}';
    } else {
      // Phát thuật ngữ tiếng Nhật -> Nhập định nghĩa
      final correctMeaning = card.meaning.trim().toLowerCase();
      final synonyms = card.meaning
          .split(RegExp(r'[,;/]'))
          .map((s) => s.trim().toLowerCase())
          .where((s) => s.isNotEmpty)
          .toList();
      isMatch = userInput == correctMeaning ||
          synonyms.contains(userInput) ||
          userInput == card.term.trim().toLowerCase() ||
          (card.reading != null && userInput == card.reading!.trim().toLowerCase());
      fullAnswerDisplay = '${card.meaning} (${card.term})';
    }

    setState(() {
      _isCorrect = isMatch;
      _feedbackMessage = isMatch ? 'Chính xác! $fullAnswerDisplay' : 'Đáp án đúng: $fullAnswerDisplay';
    });

    _service.submitAnswer(card.cardId, isMatch);

    Future.delayed(const Duration(milliseconds: 1600), () {
      if (!mounted) return;
      if (_currentIndex < _cards.length - 1) {
        setState(() {
          _currentIndex++;
          _inputController.clear();
          _isCorrect = null;
          _feedbackMessage = null;
        });
        _focusNode.requestFocus();
        _playCurrentAudio();
      } else {
        _showCompleted();
      }
    });
  }

  void _onSkip() {
    if (_cards.isEmpty) return;
    final card = _cards[_currentIndex];
    final isDefinition = _options.displayFrontFace == 'definition';

    String fullAnswerDisplay;
    if (isDefinition) {
      final readingPart = (card.reading != null &&
              card.reading!.trim().isNotEmpty &&
              card.reading!.trim().toLowerCase() != card.term.trim().toLowerCase())
          ? ' (${card.reading})'
          : '';
      fullAnswerDisplay = '${card.term}$readingPart: ${card.meaning}';
    } else {
      fullAnswerDisplay = '${card.meaning} (${card.term})';
    }

    setState(() {
      _isCorrect = false;
      _feedbackMessage = 'Đáp án đúng: $fullAnswerDisplay';
    });
    _service.submitAnswer(card.cardId, false);

    Future.delayed(const Duration(milliseconds: 1600), () {
      if (!mounted) return;
      if (_currentIndex < _cards.length - 1) {
        setState(() {
          _currentIndex++;
          _inputController.clear();
          _isCorrect = null;
          _feedbackMessage = null;
        });
        _focusNode.requestFocus();
        _playCurrentAudio();
      } else {
        _showCompleted();
      }
    });
  }

  void _showCompleted() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.flashCardSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hoàn thành bài luyện nghe!', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Bạn đã hoàn tất tất cả câu hỏi luyện nghe trong bộ thẻ.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.flashCoral),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Đóng', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.flashBackground,
        body: Center(child: CircularProgressIndicator(color: AppColors.flashCoral)),
      );
    }

    if (_cards.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.flashBackground,
        body: SafeArea(
          child: Column(
            children: [
              LearningHeader(
                currentIndex: 0,
                totalItems: 0,
                onClose: () => Navigator.pop(context),
                onSettingsClick: _openSettings,
              ),
              Expanded(
                child: SimpleEmptyState(
                  message: _options.starredOnly
                      ? 'Không có từ vựng nào được gắn sao.'
                      : 'Không có từ vựng nào trong danh sách.',
                  onBack: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.flashBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar & Progress Bar
            LearningHeader(
              currentIndex: _currentIndex + 1,
              totalItems: _cards.length,
              onClose: () => Navigator.pop(context),
              onSettingsClick: _openSettings,
            ),

            const SizedBox(height: 12),

            // 1. Audio Question Card: Siêu tối giản với duy nhất 1 nút loa ở giữa & badge tốc độ góc phải
            Container(
              width: double.infinity,
              height: 250,
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: AppColors.socialSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Nút Loa âm thanh chính nằm CHÍNH GIỮA thẻ kèm text "Chạm để nghe"
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 124,
                          height: 124,
                          child: Stack(
                            alignment: Alignment.center,
                            clipBehavior: Clip.none,
                            children: [
                              // Sóng âm lan tỏa mờ xung quanh khi phát âm thanh
                              if (_isPlayingAudio)
                                AnimatedBuilder(
                                  animation: _pulseAnimation,
                                  builder: (context, child) {
                                    final waveScale = _pulseAnimation.value;
                                    final waveOpacity =
                                        ((1.20 - waveScale) / 0.20 * 0.45).clamp(0.0, 0.45);
                                    return Container(
                                      width: 90 * waveScale + 14,
                                      height: 90 * waveScale + 14,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: AppColors.flashCoral.withValues(alpha: waveOpacity),
                                          width: 2.0,
                                        ),
                                      ),
                                    );
                                  },
                                ),

                              // Nút loa tròn lớn nổi bật (~90px)
                              GestureDetector(
                                onTapDown: (_) => setState(() => _isButtonPressed = true),
                                onTapUp: (_) {
                                  setState(() => _isButtonPressed = false);
                                  _playCurrentAudio();
                                },
                                onTapCancel: () => setState(() => _isButtonPressed = false),
                                child: AnimatedScale(
                                  scale: _isButtonPressed ? 0.94 : 1.0,
                                  duration: const Duration(milliseconds: 100),
                                  child: Container(
                                    width: 90,
                                    height: 90,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.flashAudioButton,
                                      border: Border.all(
                                        color: _isPlayingAudio
                                            ? AppColors.flashCoral
                                            : Colors.white.withValues(alpha: 0.12),
                                        width: _isPlayingAudio ? 2.5 : 1.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: _isPlayingAudio
                                              ? AppColors.flashCoral.withValues(alpha: 0.35)
                                              : Colors.black.withValues(alpha: 0.3),
                                          blurRadius: _isPlayingAudio ? 24 : 12,
                                          spreadRadius: _isPlayingAudio ? 3 : 0,
                                        ),
                                      ],
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.volume_up_rounded,
                                        size: 46,
                                        color: AppColors.flashCoral,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Dòng text mờ hướng dẫn
                        const Text(
                          'Chạm để nghe',
                          style: TextStyle(
                            color: AppColors.socialTextMuted,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 2. Nút chuyển tốc độ dạng badge thu nhỏ tối giản ở GÓC DƯỚI BÊN PHẢI thẻ
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: GestureDetector(
                      onTap: _toggleSpeed,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                            width: 1.0,
                          ),
                        ),
                        child: Text(
                          _speechRate == 0.7 ? '0.7x' : '1.0x',
                          style: const TextStyle(
                            color: AppColors.socialTextMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Feedback Message (Chính xác / Đáp án đúng)
            if (_feedbackMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Text(
                  _feedbackMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _isCorrect == true ? AppColors.modeQuiz : AppColors.flashAccent,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

            // Nút "Không biết" ở góc phải
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _onSkip,
                  child: const Text(
                    'Không biết',
                    style: TextStyle(
                      color: AppColors.modeTyping,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),

            // Vùng nhập liệu gạch chân với gợi ý phù hợp theo mặt thẻ phát âm
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
              child: TextField(
                controller: _inputController,
                focusNode: _focusNode,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _checkAnswer(),
                decoration: InputDecoration(
                  hintText: _options.displayFrontFace == 'definition'
                      ? 'NHẬP THUẬT NGỮ BẠN NGHE ĐƯỢC'
                      : 'NHẬP ĐỊNH NGHĨA BẠN NGHE ĐƯỢC',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                  enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.modeTyping, width: 2),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.flashCoral, width: 2.5),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
