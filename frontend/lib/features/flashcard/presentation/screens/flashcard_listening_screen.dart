import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/services/tts_service.dart';
import '../../data/models/flashcard_item_model.dart';
import '../../data/models/flashcard_set_model.dart';
import '../../data/services/flashcard_service.dart';
import '../widgets/answer_streak.dart';
import '../widgets/completion_fireworks.dart';
import '../widgets/fire_celebration.dart';
import '../widgets/learning_header.dart';
import '../widgets/simple_empty_state.dart';
import '../widgets/study_options_bottom_sheet.dart';
import '../../../../core/theme/app_palette.dart';

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

class _FlashcardListeningScreenState extends State<FlashcardListeningScreen> {
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final FlashcardService _service = FlashcardService.instance;

  List<FlashcardItemModel> _cards = [];
  int _totalCards = 0;
  int _currentIndex = 0;
  bool _isLoading = true;
  String? _feedbackMessage;
  bool? _isCorrect;

  /// Chuỗi trả lời đúng liên tiếp (đổi màu thanh tiến trình, hiện lửa) và bộ đếm để chơi hiệu ứng lửa lớn.
  final AnswerStreak _streak = AnswerStreak();
  final Set<int> _masteredCardIds = {};
  int _fireTrigger = 0;

  bool _isPlayingAudio = false;
  bool _isButtonPressed = false;

  Timer? _audioTimeoutTimer;

  late StudyOptions _options;

  @override
  void initState() {
    super.initState();
    _options = widget.options?.copyWith() ?? StudyOptions();

    _loadCards();
  }

  @override
  void dispose() {
    _stopAudio();
    _inputController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadCards() async {
    _streak.reset();
    _masteredCardIds.clear();
    setState(() => _isLoading = true);
    final list = await _service.getCardsInSet(
      widget.deck.setId,
      starredOnly: _options.starredOnly,
      shuffle: _options.shuffle,
    );
    if (mounted) {
      setState(() {
        _cards = list;
        _totalCards = list.length;
        _currentIndex = 0;
        _inputController.clear();
        _isCorrect = null;
        _feedbackMessage = null;
        _isLoading = false;
      });
      _focusAnswerInput();
      if (_cards.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 350), () {
          if (mounted) _playCurrentAudio();
        });
      }
    }
  }

  void _focusAnswerInput() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _focusNode.canRequestFocus) _focusNode.requestFocus();
    });
  }

  void _stopAudio() {
    _audioTimeoutTimer?.cancel();
    _audioTimeoutTimer = null;
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

    _audioTimeoutTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) _stopAudio();
    });

    TtsService.speak(
      text: textToSpeak,
      lang: langCode,
      rate: 1.0,
      onStart: () {
        if (mounted && !_isPlayingAudio) {
          setState(() => _isPlayingAudio = true);
        }
      },
      onComplete: () {
        if (mounted) _stopAudio();
      },
    );
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
    String correctAnswerDisplay;

    if (isDefinition) {
      // Phát định nghĩa tiếng Việt -> Nhập lại định nghĩa tiếng Việt.
      final correctMeaning = card.meaning.trim().toLowerCase();
      final synonyms = card.meaning
          .split(RegExp(r'[,;/]'))
          .map((s) => s.trim().toLowerCase())
          .where((s) => s.isNotEmpty)
          .toList();
      isMatch = userInput == correctMeaning || synonyms.contains(userInput);
      correctAnswerDisplay = card.meaning;
    } else {
      // Phát thuật ngữ tiếng Nhật -> Nhập lại thuật ngữ tiếng Nhật.
      final correctTerm = card.term.trim().toLowerCase();
      final correctReading = (card.reading ?? '').trim().toLowerCase();
      isMatch = userInput == correctTerm ||
          (correctReading.isNotEmpty && userInput == correctReading);

      final readingPart = card.reading != null &&
              card.reading!.trim().isNotEmpty &&
              card.reading!.trim().toLowerCase() != card.term.trim().toLowerCase()
          ? ' (${card.reading})'
          : '';
      correctAnswerDisplay = '${card.term}$readingPart';
    }

    final reachedFireMilestone = _streak.record(correct: isMatch);
    setState(() {
      if (reachedFireMilestone) _fireTrigger++;
      if (isMatch) _masteredCardIds.add(card.cardId);
      _isCorrect = isMatch;
      _feedbackMessage = isMatch ? 'Chính xác!' : 'Đáp án đúng: $correctAnswerDisplay';
    });

    _service.submitAnswer(card.cardId, isMatch);

    Future.delayed(
      Duration(milliseconds: reachedFireMilestone ? 2100 : 1600),
      () => _advanceToNext(retryCard: isMatch ? null : card),
    );
  }

  void _onSkip() {
    if (_cards.isEmpty || _feedbackMessage != null) return;
    final card = _cards[_currentIndex];
    final isDefinition = _options.displayFrontFace == 'definition';
    final readingPart = card.reading != null &&
            card.reading!.trim().isNotEmpty &&
            card.reading!.trim().toLowerCase() != card.term.trim().toLowerCase()
        ? ' (${card.reading})'
        : '';
    final correctAnswerDisplay = isDefinition
        ? card.meaning
        : '${card.term}$readingPart';

    _streak.record(correct: false);
    setState(() {
      _isCorrect = false;
      _feedbackMessage = 'Đáp án đúng: $correctAnswerDisplay';
    });
    _service.submitAnswer(card.cardId, false);
    Future.delayed(
      const Duration(milliseconds: 1600),
      () => _advanceToNext(retryCard: card),
    );
  }

  void _advanceToNext({FlashcardItemModel? retryCard}) {
    if (!mounted) return;
    if (retryCard != null || _currentIndex < _cards.length - 1) {
      setState(() {
        if (retryCard != null) _cards.add(retryCard);
        _currentIndex++;
        _inputController.clear();
        _isCorrect = null;
        _feedbackMessage = null;
      });
      _focusAnswerInput();
      _playCurrentAudio();
    } else {
      _showCompleted();
    }
  }

  void _showCompleted() {
    showDialog(
      context: context,
      builder: (ctx) => Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          const IgnorePointer(child: CompletionFireworks()),
          Center(
            child: AlertDialog(
              backgroundColor: AppPalette.background,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text('Hoàn thành bài luyện nghe!', style: TextStyle(color: AppPalette.textPrimary)),
              content: Text(
                'Bạn đã hoàn tất tất cả câu hỏi luyện nghe trong bộ thẻ.',
                style: TextStyle(color: AppPalette.textSecondary),
              ),
              actions: [
                TextButton(
                  key: const ValueKey('listening-restart'),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _loadCards();
                  },
                  child: Text('Học lại', style: TextStyle(color: AppPalette.textPrimary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppPalette.accent),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context);
                  },
                  child: Text('Đóng', style: TextStyle(color: AppPalette.onAccent)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppPalette.background,
        body: Center(child: CircularProgressIndicator(color: AppPalette.accent)),
      );
    }

    if (_cards.isEmpty) {
      return Scaffold(
        backgroundColor: AppPalette.background,
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

    final displayIndex = _isCorrect == null
        ? math.min(_masteredCardIds.length + 1, _totalCards)
        : math.min(_masteredCardIds.length + (_isCorrect == true ? 0 : 1), _totalCards);

    return Scaffold(
      backgroundColor: AppPalette.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          SafeArea(
            child: Column(
              children: [
                // Top Bar & Progress Bar
                LearningHeader(
                  currentIndex: displayIndex,
                  completedItems: _masteredCardIds.length,
                  totalItems: _totalCards,
                  streak: _streak.count,
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
                    color: AppPalette.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppPalette.textPrimary.withValues(alpha: 0.08)),
                    boxShadow: [
                      BoxShadow(
                        color: AppPalette.shadow,
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
                            GestureDetector(
                              onTapDown: (_) =>
                                  setState(() => _isButtonPressed = true),
                              onTapUp: (_) {
                                setState(() => _isButtonPressed = false);
                                _playCurrentAudio();
                              },
                              onTapCancel: () =>
                                  setState(() => _isButtonPressed = false),
                              child: AnimatedScale(
                                scale: _isButtonPressed ? 0.94 : 1.0,
                                duration: const Duration(milliseconds: 100),
                                child: Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppPalette.accent,
                                  ),
                                  child: Icon(
                                    Icons.volume_up_rounded,
                                    size: 40,
                                    color: AppPalette.onAccent,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 18),

                            // Dòng text mờ hướng dẫn
                            Text(
                              'Chạm để nghe câu',
                              style: TextStyle(
                                color: AppPalette.textSecondary,
                                fontSize: 16,
                              ),
                            ),
                          ],
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
                        color: _isCorrect == true ? AppPalette.success : AppPalette.error,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      key: const ValueKey('listening-skip'),
                      onPressed: _feedbackMessage == null ? _onSkip : null,
                      child: Text(
                        'Không biết',
                        style: TextStyle(
                          color: _feedbackMessage == null
                              ? AppPalette.accent
                              : AppPalette.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),

                // Ô nghe-viết và nút kiểm tra đáp án.
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                  child: Column(
                    children: [
                      TextField(
                        controller: _inputController,
                        focusNode: _focusNode,
                        enabled: _feedbackMessage == null,
                        minLines: 4,
                        maxLines: 5,
                        onChanged: (_) => setState(() {}),
                        style: TextStyle(
                          color: AppPalette.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        textInputAction: TextInputAction.newline,
                        decoration: InputDecoration(
                          hintText: 'Gõ lại câu bạn vừa nghe...',
                          hintStyle: TextStyle(
                            color: AppPalette.textSecondary,
                            fontSize: 16,
                          ),
                          filled: true,
                          fillColor: AppPalette.background,
                          contentPadding: const EdgeInsets.all(16),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: AppPalette.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: AppPalette.accent,
                              width: 1.5,
                            ),
                          ),
                          disabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: AppPalette.border),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton(
                          onPressed:
                              _inputController.text.trim().isEmpty ||
                                  _feedbackMessage != null
                              ? null
                              : _checkAnswer,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppPalette.accent,
                            foregroundColor: AppPalette.onAccent,
                            disabledBackgroundColor: AppPalette.surfaceHigh,
                            disabledForegroundColor: AppPalette.textSecondary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Kiểm tra đáp án',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Hiệu ứng lửa lớn khi đúng 5 câu liên tiếp
          FireCelebration(trigger: _fireTrigger, streak: _streak.count),
        ],
      ),
    );
  }
}
