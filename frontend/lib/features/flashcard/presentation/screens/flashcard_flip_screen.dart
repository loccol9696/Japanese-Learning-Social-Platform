import 'dart:math';
import 'package:flutter/material.dart';
import '../../data/models/flashcard_item_model.dart';
import '../../data/models/flashcard_set_model.dart';
import '../../data/services/flashcard_service.dart';
import '../widgets/study_options_bottom_sheet.dart';

class FlashcardFlipScreen extends StatefulWidget {
  final FlashcardSetModel deck;

  const FlashcardFlipScreen({super.key, required this.deck});

  @override
  State<FlashcardFlipScreen> createState() => _FlashcardFlipScreenState();
}

class _FlashcardFlipScreenState extends State<FlashcardFlipScreen>
    with SingleTickerProviderStateMixin {
  final FlashcardService _service = FlashcardService.instance;
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;

  List<FlashcardItemModel> _cards = [];
  int _currentIndex = 0;
  bool _isFront = true;
  bool _isLoading = true;
  StudyOptions _options = StudyOptions();

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _flipAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_flipController);
    _loadCards();
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
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
    _service.submitAnswer(_cards[_currentIndex].cardId, mastered);

    if (_currentIndex < _cards.length - 1) {
      setState(() {
        _currentIndex++;
        _isFront = true;
        _flipController.reset();
      });
    } else {
      _showCompletionDialog();
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161922),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hoàn thành xuất sắc!', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Bạn đã hoàn thành lượt ôn tập cho bộ từ vựng này.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF2D55)),
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
    final progress = total > 0 ? displayIndex / total : 0.0;
    final currentCard = _cards.isNotEmpty ? _cards[_currentIndex] : null;

    return Scaffold(
      backgroundColor: const Color(0xFF0C0E14),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar: Close, Counter, Settings
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Text(
                    '$displayIndex / $total',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings, color: Colors.white),
                    onPressed: _openSettings,
                  ),
                ],
              ),
            ),

            // Linear Progress Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 3.5,
                  backgroundColor: const Color(0xFF1E2332),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF2D55)),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Giant Center Flashcard
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF2D55)))
                  : currentCard == null
                      ? const Center(
                          child: Text(
                            'Không có từ vựng nào trong danh sách!',
                            style: TextStyle(color: Colors.white54),
                          ),
                        )
                      : GestureDetector(
                          onTap: _flipCard,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            child: AnimatedBuilder(
                              animation: _flipAnimation,
                              builder: (context, child) {
                                final angle = _flipAnimation.value * pi;
                                final isUnder = angle > pi / 2;

                                return Transform(
                                  transform: Matrix4.identity()
                                    ..setEntry(3, 2, 0.001)
                                    ..rotateY(angle),
                                  alignment: Alignment.center,
                                  child: isUnder
                                      ? Transform(
                                          transform: Matrix4.identity()..rotateY(pi),
                                          alignment: Alignment.center,
                                          child: _buildCardBack(currentCard),
                                        )
                                      : _buildCardFront(currentCard),
                                );
                              },
                            ),
                          ),
                        ),
            ),

            // Bottom action hint / buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.white.withOpacity(0.15)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => _nextCard(false),
                      child: const Text('Chưa nhớ', style: TextStyle(color: Colors.white70)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF2D55),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => _nextCard(true),
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

  Widget _buildCardFront(FlashcardItemModel card) {
    final displayText = _options.frontLanguage == 'ja' ? card.term : card.meaning;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF161924),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Stack(
        children: [
          // Audio & Star icons
          Positioned(
            top: 20,
            left: 20,
            child: IconButton(
              icon: Icon(Icons.volume_up, color: Colors.white.withOpacity(0.6), size: 26),
              onPressed: () {},
            ),
          ),
          Positioned(
            top: 20,
            right: 20,
            child: IconButton(
              icon: Icon(
                card.isStarred ? Icons.star : Icons.star_border,
                color: card.isStarred ? const Color(0xFFFFCC00) : Colors.white.withOpacity(0.4),
                size: 26,
              ),
              onPressed: _toggleStar,
            ),
          ),
          // Word
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 44,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Chạm để lật thẻ',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 13,
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

  Widget _buildCardBack(FlashcardItemModel card) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1B2030),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFFF2D55).withOpacity(0.4), width: 1.5),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 20,
            left: 20,
            child: IconButton(
              icon: Icon(Icons.volume_up, color: Colors.white.withOpacity(0.6), size: 26),
              onPressed: () {},
            ),
          ),
          Positioned(
            top: 20,
            right: 20,
            child: IconButton(
              icon: Icon(
                card.isStarred ? Icons.star : Icons.star_border,
                color: card.isStarred ? const Color(0xFFFFCC00) : Colors.white.withOpacity(0.4),
                size: 26,
              ),
              onPressed: _toggleStar,
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(28.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (card.reading != null && card.reading!.isNotEmpty)
                    Text(
                      card.reading!,
                      style: const TextStyle(color: Color(0xFFFF5E7E), fontSize: 24, fontWeight: FontWeight.w600),
                    ),
                  const SizedBox(height: 8),
                  if (card.sinoVietnamese != null && card.sinoVietnamese!.isNotEmpty)
                    Text(
                      card.sinoVietnamese!,
                      style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    card.meaning,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700),
                  ),
                  if (card.example != null && card.example!.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Divider(color: Colors.white.withOpacity(0.1)),
                    const SizedBox(height: 12),
                    Text(
                      card.example!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14, fontStyle: FontStyle.italic),
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
