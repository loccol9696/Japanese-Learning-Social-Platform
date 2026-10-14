import 'package:flutter/material.dart';
import '../../data/models/flashcard_set_model.dart';
import '../../data/models/quiz_question_model.dart';
import '../../data/services/flashcard_service.dart';
import '../widgets/segmented_progress_bar.dart';

class FlashcardQuizScreen extends StatefulWidget {
  final FlashcardSetModel deck;

  const FlashcardQuizScreen({super.key, required this.deck});

  @override
  State<FlashcardQuizScreen> createState() => _FlashcardQuizScreenState();
}

class _FlashcardQuizScreenState extends State<FlashcardQuizScreen> {
  final FlashcardService _service = FlashcardService.instance;
  List<QuizQuestionModel> _questions = [];
  int _currentIndex = 0;
  bool _isLoading = true;
  String? _selectedOption;

  @override
  void initState() {
    super.initState();
    _loadQuiz();
  }

  Future<void> _loadQuiz() async {
    final list = await _service.getQuizQuestions(widget.deck.setId);
    if (mounted) {
      setState(() {
        _questions = list;
        _currentIndex = 0;
        _selectedOption = null;
        _isLoading = false;
      });
    }
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
        backgroundColor: const Color(0xFF161922),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hoàn thành bài trắc nghiệm!', style: TextStyle(color: Colors.white)),
        content: const Text('Bạn đã hoàn tất tất cả câu hỏi.', style: TextStyle(color: Colors.white70)),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF2D55)),
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
        backgroundColor: Color(0xFF0C0E14),
        body: Center(child: CircularProgressIndicator(color: Color(0xFFFF2D55))),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF0C0E14),
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Không có câu hỏi trắc nghiệm', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Quay lại'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final q = _questions[_currentIndex];

    return Scaffold(
      backgroundColor: const Color(0xFF0C0E14),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: SegmentedProgressBar(
                        currentIndex: _currentIndex + 1,
                        totalCount: _questions.length,
                        segmentCount: 5,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings, color: Colors.white),
                    onPressed: () {},
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Question Card (Screenshot 210607)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF1B1E2B),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Column(
                children: [
                  Text(
                    q.term,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (q.sinoVietnamese != null && q.sinoVietnamese!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      q.sinoVietnamese!,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    q.meaning,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
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
                    color: Colors.white.withOpacity(0.55),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 4 Option Buttons
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                physics: const NeverScrollableScrollPhysics(),
                itemCount: q.options.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final opt = q.options[index];
                  Color btnBg = const Color(0xFF161922);
                  Color borderColor = Colors.white.withOpacity(0.08);

                  if (_selectedOption != null) {
                    if (opt == q.correctAnswer) {
                      btnBg = const Color(0xFF0F382E);
                      borderColor = const Color(0xFF00C7B1);
                    } else if (opt == _selectedOption) {
                      btnBg = const Color(0xFF38151D);
                      borderColor = const Color(0xFFFF2D55);
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
                      color: Colors.white.withOpacity(0.45),
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
