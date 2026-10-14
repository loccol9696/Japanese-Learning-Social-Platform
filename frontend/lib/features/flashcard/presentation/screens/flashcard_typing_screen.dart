import 'package:flutter/material.dart';
import '../../data/models/flashcard_item_model.dart';
import '../../data/models/flashcard_set_model.dart';
import '../../data/services/flashcard_service.dart';
import '../widgets/segmented_progress_bar.dart';

class FlashcardTypingScreen extends StatefulWidget {
  final FlashcardSetModel deck;

  const FlashcardTypingScreen({super.key, required this.deck});

  @override
  State<FlashcardTypingScreen> createState() => _FlashcardTypingScreenState();
}

class _FlashcardTypingScreenState extends State<FlashcardTypingScreen> {
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final FlashcardService _service = FlashcardService.instance;

  List<FlashcardItemModel> _cards = [];
  int _currentIndex = 0;
  bool _isLoading = true;
  String? _feedbackMessage;
  bool? _isCorrect;

  @override
  void initState() {
    super.initState();
    _loadCards();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadCards() async {
    final list = await _service.getCardsInSet(widget.deck.setId);
    if (mounted) {
      setState(() {
        _cards = list;
        _currentIndex = 0;
        _isLoading = false;
      });
      _focusNode.requestFocus();
    }
  }

  void _checkAnswer() {
    if (_cards.isEmpty || _inputController.text.trim().isEmpty) return;

    final card = _cards[_currentIndex];
    final userInput = _inputController.text.trim().toLowerCase();
    final correctReading = (card.reading ?? '').trim().toLowerCase();
    final correctTerm = card.term.trim().toLowerCase();

    final isMatch = userInput == correctReading || userInput == correctTerm;

    setState(() {
      _isCorrect = isMatch;
      _feedbackMessage = isMatch
          ? 'Chính xác!'
          : 'Đáp án đúng: ${card.reading ?? card.term}';
    });

    _service.submitAnswer(card.cardId, isMatch);

    Future.delayed(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      if (_currentIndex < _cards.length - 1) {
        setState(() {
          _currentIndex++;
          _inputController.clear();
          _isCorrect = null;
          _feedbackMessage = null;
        });
        _focusNode.requestFocus();
      } else {
        _showCompleted();
      }
    });
  }

  void _onSkip() {
    if (_cards.isEmpty) return;
    final card = _cards[_currentIndex];
    setState(() {
      _isCorrect = false;
      _feedbackMessage = 'Đáp án đúng: ${card.reading ?? card.term}';
    });
    _service.submitAnswer(card.cardId, false);

    Future.delayed(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      if (_currentIndex < _cards.length - 1) {
        setState(() {
          _currentIndex++;
          _inputController.clear();
          _isCorrect = null;
          _feedbackMessage = null;
        });
        _focusNode.requestFocus();
      } else {
        _showCompleted();
      }
    });
  }

  void _showCompleted() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161922),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hoàn thành bài tự luận!', style: TextStyle(color: Colors.white)),
        content: const Text('Bạn đã hoàn tất tất cả câu hỏi tự luận.', style: TextStyle(color: Colors.white70)),
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

    if (_cards.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF0C0E14),
        body: Center(
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Không có từ vựng. Quay lại', style: TextStyle(color: Colors.white)),
          ),
        ),
      );
    }

    final card = _cards[_currentIndex];

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
                        totalCount: _cards.length,
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

            // Question Card (Screenshot 210625)
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
                    card.term,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (card.sinoVietnamese != null && card.sinoVietnamese!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      card.sinoVietnamese!,
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
                    card.meaning,
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

            const Spacer(),

            // Feedback Message
            if (_feedbackMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Text(
                  _feedbackMessage!,
                  style: TextStyle(
                    color: _isCorrect == true ? const Color(0xFF00C7B1) : const Color(0xFFFF2D55),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

            // Text Link: "Không biết"
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _onSkip,
                  child: const Text(
                    'Không biết',
                    style: TextStyle(
                      color: Color(0xFF5E81F4),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),

            // Underline Input Field
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
                  hintText: 'NHẬP BẰNG TIẾNG NHẬT',
                  hintStyle: TextStyle(
                    color: Colors.white.withOpacity(0.35),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                  enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF5E81F4), width: 2),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFFF2D55), width: 2.5),
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
