import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../data/models/flashcard_item_model.dart';
import '../../data/models/flashcard_set_model.dart';
import '../../data/models/quiz_question_model.dart';
import '../../data/services/flashcard_service.dart';
import '../widgets/answer_streak.dart';
import '../widgets/fire_celebration.dart';
import '../widgets/learning_header.dart';
import '../widgets/simple_empty_state.dart';
import '../widgets/study_options_bottom_sheet.dart';
import '../../../../core/theme/app_palette.dart';

/// Thuật toán tạo danh sách đáp án (options) cho câu hỏi Trắc nghiệm
List<String> generateQuizOptions(
  FlashcardItemModel currentCard,
  List<FlashcardItemModel> allCards, {
  bool optionsInJapanese = true,
}) {
  // 1. Xác định số lượng đáp án hiển thị (Option Count) = Math.min(4, allCards.length)
  final optionCount = math.min(4, allCards.length);
  final correctAnswer = optionsInJapanese
      ? ((currentCard.reading != null && currentCard.reading!.trim().isNotEmpty)
          ? currentCard.reading!.trim()
          : currentCard.term.trim())
      : currentCard.meaning.trim();

  if (optionCount <= 1) {
    return [correctAnswer];
  }

  // Bước 1: Đưa đáp án đúng (Correct Answer) vào mảng options
  final List<String> options = [correctAnswer];

  // Bước 2: Lọc ra danh sách các thẻ CÒN LẠI (bỏ thẻ hiện tại đi) để làm nguồn lấy đáp án sai
  final otherCards = allCards
      .where((card) => card.cardId != currentCard.cardId)
      .toList();

  // Bước 3: Trộn ngẫu nhiên (Shuffle) danh sách còn lại đó
  otherCards.shuffle();

  // Bước 4: Lấy số lượng đáp án sai cần thiết (bằng Option Count - 1)
  final neededDistractors = optionCount - 1;
  final Set<String> chosenDistractors = {};

  for (final other in otherCards) {
    final distractor = optionsInJapanese
        ? ((other.reading != null && other.reading!.trim().isNotEmpty)
            ? other.reading!.trim()
            : other.term.trim())
        : other.meaning.trim();

    if (distractor.toLowerCase() != correctAnswer.toLowerCase() &&
        !chosenDistractors.contains(distractor)) {
      chosenDistractors.add(distractor);
      if (chosenDistractors.length >= neededDistractors) {
        break;
      }
    }
  }

  // Bước 5: Đưa các đáp án sai đã lấy vào mảng options
  options.addAll(chosenDistractors);

  // Bước 6: Trộn ngẫu nhiên lại toàn bộ mảng options một lần cuối trước khi render ra UI
  options.shuffle();

  return options;
}

class FlashcardQuizScreen extends StatefulWidget {
  final FlashcardSetModel deck;
  final StudyOptions? options;

  const FlashcardQuizScreen({super.key, required this.deck, this.options});

  @override
  State<FlashcardQuizScreen> createState() => _FlashcardQuizScreenState();
}

class _FlashcardQuizScreenState extends State<FlashcardQuizScreen> {
  final FlashcardService _service = FlashcardService.instance;
  List<QuizQuestionModel> _questions = [];
  int _currentIndex = 0;
  bool _isLoading = true;
  String? _selectedOption;
  late StudyOptions _options;

  /// Chuỗi trả lời đúng liên tiếp (đổi màu thanh tiến trình, hiện lửa) và bộ đếm để chơi hiệu ứng lửa lớn.
  final AnswerStreak _streak = AnswerStreak();
  int _fireTrigger = 0;

  /// Trả lời sai thì chờ người dùng bấm "Tiếp tục"; trả lời đúng thì tự chuyển câu.
  bool _awaitingContinue = false;
  Timer? _advanceTimer;

  static const Duration _autoAdvance = Duration(milliseconds: 1100);
  static const Duration _autoAdvanceAfterFire = Duration(milliseconds: 1900);

  @override
  void initState() {
    super.initState();
    _options = widget.options ?? StudyOptions();
    _loadQuiz();
  }


  @override
  void dispose() {
    _advanceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadQuiz() async {
    _advanceTimer?.cancel();
    _streak.reset();
    _awaitingContinue = false;
    setState(() => _isLoading = true);

    // 1. Tải tất cả các thẻ trong bộ để dùng làm nguồn đáp án sai (distractors)
    final allCardsInDeck = await _service.getCardsInSet(
      widget.deck.setId,
      starredOnly: false,
    );

    // 2. Lọc danh sách thẻ mục tiêu dựa trên tùy chọn học (starredOnly & shuffle)
    List<FlashcardItemModel> targetCards = allCardsInDeck;
    if (_options.starredOnly) {
      targetCards = targetCards.where((c) => c.isStarred).toList();
    }
    if (_options.shuffle) {
      targetCards = List.of(targetCards)..shuffle();
    }

    if (targetCards.isEmpty) {
      if (mounted) {
        setState(() {
          _questions = [];
          _currentIndex = 0;
          _selectedOption = null;
          _isLoading = false;
        });
      }
      return;
    }

    // 3. Xác định hướng câu hỏi & đáp án theo "Mặt thẻ hiển thị trước":
    // - Thuật ngữ (displayFrontFace == 'term'): Câu hỏi là Thuật ngữ (JA) -> Options là Định nghĩa (VI)
    // - Định nghĩa (displayFrontFace == 'definition'): Câu hỏi là Định nghĩa (VI) -> Options là Thuật ngữ (JA)
    final bool optionsInJapanese = _options.displayFrontFace == 'definition';

    final List<QuizQuestionModel> generatedQuestions = targetCards.map((card) {
      final cleanOptions = generateQuizOptions(
        card,
        allCardsInDeck,
        optionsInJapanese: optionsInJapanese,
      );

      final correctAnswer = optionsInJapanese
          ? ((card.reading != null && card.reading!.trim().isNotEmpty)
              ? card.reading!.trim()
              : card.term.trim())
          : card.meaning.trim();

      return QuizQuestionModel(
        cardId: card.cardId,
        term: card.term,
        sinoVietnamese: card.sinoVietnamese,
        meaning: card.meaning,
        correctAnswer: correctAnswer,
        options: cleanOptions,
      );
    }).toList();

    if (mounted) {
      setState(() {
        _questions = generatedQuestions;
        _currentIndex = 0;
        _selectedOption = null;
        _isLoading = false;
      });
    }
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
          _loadQuiz();
        },
        onResetProgress: () async {
          await _service.resetProgress(widget.deck.setId);
          _loadQuiz();
        },
      ),
    );
  }

  void _onSelectOption(String option) {
    if (_selectedOption != null) return; // Already answered

    final q = _questions[_currentIndex];
    final isCorrect = option == q.correctAnswer;
    final reachedFireMilestone = _streak.record(correct: isCorrect);

    setState(() {
      _selectedOption = option;
      _awaitingContinue = !isCorrect;
      if (reachedFireMilestone) _fireTrigger++;
    });

    _service.submitAnswer(q.cardId, isCorrect);

    // Đúng: tự sang câu sau (chờ lâu hơn một chút để kịp xem hiệu ứng lửa). Sai: chờ bấm "Tiếp tục".
    if (isCorrect) {
      _advanceTimer?.cancel();
      _advanceTimer = Timer(reachedFireMilestone ? _autoAdvanceAfterFire : _autoAdvance, _goNext);
    }
  }

  void _goNext() {
    if (!mounted) return;
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedOption = null;
        _awaitingContinue = false;
      });
    } else {
      _showQuizCompleted();
    }
  }

  void _showQuizCompleted() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppPalette.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Hoàn thành bài trắc nghiệm!', style: TextStyle(color: AppPalette.textPrimary)),
        content: Text('Bạn đã hoàn tất tất cả câu hỏi.', style: TextStyle(color: AppPalette.textSecondary)),
        actions: [
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

    if (_questions.isEmpty) {
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
                      : 'Không có câu hỏi trắc nghiệm.',
                  onBack: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final q = _questions[_currentIndex];
    final bool isOptionsJapanese = _options.displayFrontFace == 'definition';
    // displayFrontFace == 'term': Thẻ câu hỏi hiển thị Thuật ngữ (q.term), Options hiển thị Định nghĩa
    // displayFrontFace == 'definition': Thẻ câu hỏi hiển thị Định nghĩa (q.meaning), Options hiển thị Thuật ngữ
    final questionText = isOptionsJapanese ? q.meaning : q.term;
    final questionLabel = isOptionsJapanese ? 'Định nghĩa' : 'Thuật ngữ';

    return Scaffold(
      backgroundColor: AppPalette.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          SafeArea(
            child: Column(
              children: [
                // Thanh trên cùng + thanh tiến trình (đổi màu cam, hiện lửa khi đúng liên tiếp)
                LearningHeader(
                  currentIndex: _currentIndex + 1,
                  totalItems: _questions.length,
                  streak: _streak.count,
                  onClose: () => Navigator.pop(context),
                  onSettingsClick: _openSettings,
                ),

                const SizedBox(height: 12),

                _buildQuestionCard(questionLabel, questionText, isOptionsJapanese),

                const SizedBox(height: 24),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Chọn câu trả lời',
                      style: TextStyle(
                        color: AppPalette.textPrimary.withValues(alpha: 0.55),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: q.options.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => _buildOption(index, q.options[index], q.correctAnswer),
                  ),
                ),

                // Trả lời sai: nút "Tiếp tục" ở đáy màn hình
                if (_awaitingContinue)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton(
                        key: const ValueKey('quiz-continue'),
                        onPressed: _goNext,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppPalette.accent,
                          foregroundColor: AppPalette.onAccent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        child: const Text('Tiếp tục'),
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 20),
              ],
            ),
          ),

          // Hiệu ứng lửa lớn khi đúng 5 câu liên tiếp
          FireCelebration(trigger: _fireTrigger),
        ],
      ),
    );
  }

  /// Thẻ câu hỏi: nhãn nhỏ ở góc trên trái, nội dung to ở giữa.
  Widget _buildQuestionCard(String label, String text, bool smallText) {
    return Container(
      key: const ValueKey('quiz-question-card'),
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 150),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppPalette.textPrimary.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppPalette.textPrimary.withValues(alpha: 0.55),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppPalette.textPrimary,
                fontSize: smallText ? 30 : 44,
                fontWeight: FontWeight.w800,
                height: 1.3,
                letterSpacing: smallText ? 0.3 : 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Một đáp án. Sau khi trả lời: đáp án đúng viền xanh + dấu tick, đáp án người dùng chọn sai viền đỏ + dấu ✕,
  /// các đáp án còn lại mờ đi.
  Widget _buildOption(int index, String option, String correctAnswer) {
    final answered = _selectedOption != null;
    final isCorrect = option == correctAnswer;
    final isWrongPick = answered && option == _selectedOption && !isCorrect;
    final revealCorrect = answered && isCorrect;
    final dimmed = answered && !revealCorrect && !isWrongPick;

    Color background = AppPalette.surface;
    Color border = AppPalette.textPrimary.withValues(alpha: 0.06);
    Widget? trailing;
    if (revealCorrect) {
      background = AppPalette.info.withValues(alpha: 0.12);
      border = AppPalette.info;
      trailing = Icon(Icons.check_rounded, key: ValueKey('quiz-correct-$index'), color: AppPalette.info, size: 22);
    } else if (isWrongPick) {
      background = AppPalette.error.withValues(alpha: 0.12);
      border = AppPalette.error;
      trailing = Icon(Icons.close_rounded, key: ValueKey('quiz-wrong-$index'), color: AppPalette.error, size: 22);
    } else if (dimmed) {
      background = AppPalette.surface.withValues(alpha: 0.45);
    }

    return InkWell(
      key: ValueKey('quiz-option-$index'),
      onTap: answered ? null : () => _onSelectOption(option),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 17, horizontal: 20),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border, width: revealCorrect || isWrongPick ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                option,
                style: TextStyle(
                  color: AppPalette.textPrimary.withValues(alpha: dimmed ? 0.3 : 1),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}
