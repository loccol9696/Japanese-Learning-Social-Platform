import 'package:flutter/material.dart';
import '../../data/models/flashcard_item_model.dart';
import '../../data/models/flashcard_set_model.dart';
import '../../data/services/flashcard_service.dart';
import '../widgets/learning_header.dart';
import '../widgets/simple_empty_state.dart';
import '../widgets/study_options_bottom_sheet.dart';
import '../../../../core/theme/app_palette.dart';

class FlashcardTypingScreen extends StatefulWidget {
  final FlashcardSetModel deck;
  final String? targetLanguage; // 'ja' (default) or 'vi'
  final StudyOptions? options;

  const FlashcardTypingScreen({
    super.key,
    required this.deck,
    this.targetLanguage,
    this.options,
  });

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

  late String _targetLanguage;
  late StudyOptions _options;

  @override
  void initState() {
    super.initState();
    _targetLanguage = widget.targetLanguage ?? 'ja';
    _options = widget.options?.copyWith(
      displayFrontFace: _targetLanguage == 'ja' ? 'definition' : 'term',
    ) ?? StudyOptions(displayFrontFace: _targetLanguage == 'ja' ? 'definition' : 'term');
    _loadCards();
  }

  @override
  void dispose() {
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
          setState(() {
            _options = newOptions;
            // displayFrontFace == 'definition' -> Question is definition (VI), Target Input is Japanese ('ja')
            // displayFrontFace == 'term' -> Question is term (JA), Target Input is definition ('vi')
            _targetLanguage = newOptions.displayFrontFace == 'definition' ? 'ja' : 'vi';
          });
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
    final isInputJapanese = _targetLanguage == 'ja';

    bool isMatch;
    String correctAnswerDisplay;

    if (isInputJapanese) {
      final correctReading = (card.reading ?? '').trim().toLowerCase();
      final correctTerm = card.term.trim().toLowerCase();
      isMatch = userInput == correctTerm ||
          (correctReading.isNotEmpty && userInput == correctReading);

      final hasReading = card.reading != null &&
          card.reading!.trim().isNotEmpty &&
          card.reading!.trim().toLowerCase() != card.term.trim().toLowerCase();
      correctAnswerDisplay =
          hasReading ? '${card.term} (${card.reading})' : card.term;
    } else {
      final correctMeaning = card.meaning.trim().toLowerCase();
      final synonyms = card.meaning
          .split(RegExp(r'[,;/]'))
          .map((s) => s.trim().toLowerCase())
          .where((s) => s.isNotEmpty)
          .toList();
      isMatch = userInput == correctMeaning || synonyms.contains(userInput);
      correctAnswerDisplay = card.meaning;
    }

    setState(() {
      _isCorrect = isMatch;
      _feedbackMessage =
          isMatch ? 'Chính xác!' : 'Đáp án đúng: $correctAnswerDisplay';
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
    final isInputJapanese = _targetLanguage == 'ja';

    String correctAnswerDisplay;
    if (isInputJapanese) {
      final hasReading = card.reading != null &&
          card.reading!.trim().isNotEmpty &&
          card.reading!.trim().toLowerCase() != card.term.trim().toLowerCase();
      correctAnswerDisplay =
          hasReading ? '${card.term} (${card.reading})' : card.term;
    } else {
      correctAnswerDisplay = card.meaning;
    }

    setState(() {
      _isCorrect = false;
      _feedbackMessage = 'Đáp án đúng: $correctAnswerDisplay';
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
        backgroundColor: AppPalette.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Hoàn thành bài tự luận!', style: TextStyle(color: AppPalette.textPrimary)),
        content: Text('Bạn đã hoàn tất tất cả câu hỏi tự luận.', style: TextStyle(color: AppPalette.textSecondary)),
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

    final card = _cards[_currentIndex];
    final isInputTerm = _options.displayFrontFace == 'definition';
    // Nếu mặt trước (câu hỏi) là Định nghĩa -> Yêu cầu nhập Thuật ngữ
    // Nếu mặt trước (câu hỏi) là Thuật ngữ -> Yêu cầu nhập Định nghĩa
    final questionText = isInputTerm ? card.meaning : card.term;
    final hintLabel = isInputTerm ? 'NHẬP THUẬT NGỮ' : 'NHẬP ĐỊNH NGHĨA';

    return Scaffold(
      backgroundColor: AppPalette.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar & Continuous Progress Bar
            LearningHeader(
              currentIndex: _currentIndex + 1,
              totalItems: _cards.length,
              onClose: () => Navigator.pop(context),
              onSettingsClick: _openSettings,
            ),

            const SizedBox(height: 12),

            // Question Card: Căn giữa hoàn toàn cả chiều dọc lẫn chiều ngang, ẩn hoàn toàn đáp án
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 190),
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
              decoration: BoxDecoration(
                color: AppPalette.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppPalette.textPrimary.withValues(alpha: 0.08)),
              ),
              alignment: Alignment.center,
              child: Center(
                child: Text(
                  questionText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppPalette.textPrimary,
                    fontSize: isInputTerm ? 32 : 46,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                    letterSpacing: isInputTerm ? 0.3 : 1.5,
                  ),
                ),
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
                    color: _isCorrect == true ? AppPalette.success : AppPalette.error,
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
                  child: Text(
                    'Không biết',
                    style: TextStyle(
                      color: AppPalette.accent,
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
                style: TextStyle(
                  color: AppPalette.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _checkAnswer(),
                decoration: InputDecoration(
                  hintText: hintLabel,
                  hintStyle: TextStyle(
                    color: AppPalette.textPrimary.withValues(alpha: 0.35),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: AppPalette.accent, width: 2),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: AppPalette.accent, width: 2.5),
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
