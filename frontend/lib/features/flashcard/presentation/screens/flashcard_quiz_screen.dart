import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/flashcard_item_model.dart';
import '../../data/models/flashcard_set_model.dart';
import '../../data/models/quiz_question_model.dart';
import '../../data/services/flashcard_service.dart';
import '../widgets/learning_header.dart';
import '../widgets/simple_empty_state.dart';
import '../widgets/study_options_bottom_sheet.dart';

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

  @override
  void initState() {
    super.initState();
    _options = widget.options ?? StudyOptions();
    _loadQuiz();
  }


  Future<void> _loadQuiz() async {
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

    setState(() {
      _selectedOption = option;
    });

    _service.submitAnswer(q.cardId, isCorrect);

    Future.delayed(const Duration(milliseconds: 1100), () {
      if (!mounted) return;
      if (_currentIndex < _questions.length - 1) {
        setState(() {
          _currentIndex++;
          _selectedOption = null;
        });
      } else {
        _showQuizCompleted();
      }
    });
  }

  void _onSkipQuestion() {
    if (_selectedOption != null) return;
    final q = _questions[_currentIndex];
    setState(() {
      _selectedOption = q.correctAnswer;
    });
    _service.submitAnswer(q.cardId, false);

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      if (_currentIndex < _questions.length - 1) {
        setState(() {
          _currentIndex++;
          _selectedOption = null;
        });
      } else {
        _showQuizCompleted();
      }
    });
  }

  void _showQuizCompleted() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.flashCardSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hoàn thành bài trắc nghiệm!', style: TextStyle(color: Colors.white)),
        content: const Text('Bạn đã hoàn tất tất cả câu hỏi.', style: TextStyle(color: Colors.white70)),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.flashAccent),
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
        body: Center(child: CircularProgressIndicator(color: AppColors.flashAccent)),
      );
    }

    if (_questions.isEmpty) {
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

    return Scaffold(
      backgroundColor: AppColors.flashBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar & Continuous Progress Bar
            LearningHeader(
              currentIndex: _currentIndex + 1,
              totalItems: _questions.length,
              onClose: () => Navigator.pop(context),
              onSettingsClick: _openSettings,
            ),

            const SizedBox(height: 12),

            // Question Card: Căn giữa hoàn toàn cả chiều dọc lẫn chiều ngang, ẩn hoàn toàn đáp án
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 180),
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
              decoration: BoxDecoration(
                color: AppColors.flashChoiceSurface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              alignment: Alignment.center,
              child: Center(
                child: Text(
                  questionText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isOptionsJapanese ? 32 : 46,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                    letterSpacing: isOptionsJapanese ? 0.3 : 1.5,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Instruction
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Chọn câu trả lời',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Option Buttons
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                physics: const NeverScrollableScrollPhysics(),
                itemCount: q.options.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final opt = q.options[index];
                  Color btnBg = AppColors.flashCardSurface;
                  Color borderColor = Colors.white.withValues(alpha: 0.08);

                  if (_selectedOption != null) {
                    if (opt == q.correctAnswer) {
                      btnBg = AppColors.flashCorrectBg;
                      borderColor = AppColors.modeQuiz;
                    } else if (opt == _selectedOption) {
                      btnBg = AppColors.flashWrongBg;
                      borderColor = AppColors.flashAccent;
                    }
                  }

                  return InkWell(
                    onTap: () => _onSelectOption(opt),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                      decoration: BoxDecoration(
                        color: btnBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor, width: 1.5),
                      ),
                      child: Text(
                        opt,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // "Bạn không biết?" button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 24, 20),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _onSkipQuestion,
                  child: Text(
                    'Bạn không biết?',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
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
