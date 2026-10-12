import 'package:flutter/material.dart';
import '../../data/models/flashcard_item_model.dart';
import '../../data/models/flashcard_set_model.dart';
import '../../data/services/flashcard_service.dart';
import 'flashcard_flip_screen.dart';
import 'flashcard_matching_screen.dart';
import 'flashcard_quiz_screen.dart';
import 'flashcard_typing_screen.dart';

class DeckOverviewScreen extends StatefulWidget {
  final FlashcardSetModel deck;

  const DeckOverviewScreen({super.key, required this.deck});

  @override
  State<DeckOverviewScreen> createState() => _DeckOverviewScreenState();
}

class _DeckOverviewScreenState extends State<DeckOverviewScreen> {
  final PageController _pageController = PageController();
  final FlashcardService _service = FlashcardService.instance;
  int _currentPage = 0;
  List<FlashcardItemModel> _cards = [];
  bool _isBookmarked = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCards();
  }

  Future<void> _loadCards() async {
    final cards = await _service.getCardsInSet(widget.deck.setId);
    if (mounted) {
      setState(() {
        _cards = cards;
        _isLoading = false;
      });
    }
  }

  Widget _buildModeTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161922),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: Colors.white.withOpacity(0.35),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0E14),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                          color: _isBookmarked ? const Color(0xFFFF2D55) : Colors.white,
                        ),
                        onPressed: () => setState(() => _isBookmarked = !_isBookmarked),
                      ),
                      IconButton(
                        icon: const Icon(Icons.more_vert, color: Colors.white),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Card Preview Carousel
            Container(
              height: 220,
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1B1E2B),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF2D55)))
                  : _cards.isEmpty
                      ? const Center(
                          child: Text(
                            'Chưa có từ vựng',
                            style: TextStyle(color: Colors.white54),
                          ),
                        )
                      : PageView.builder(
                          controller: _pageController,
                          itemCount: _cards.length,
                          onPageChanged: (idx) => setState(() => _currentPage = idx),
                          itemBuilder: (context, index) {
                            final card = _cards[index];
                            return Center(
                              child: Text(
                                card.term,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 40,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            );
                          },
                        ),
            ),

            // Dots Indicator
            if (_cards.isNotEmpty)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _cards.length.clamp(1, 6),
                  (index) => Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: index == _currentPage
                          ? const Color(0xFFFF2D55)
                          : Colors.white.withOpacity(0.2),
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 12),

            // Title & Author
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.deck.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF0091FF),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          widget.deck.authorName.isNotEmpty ? widget.deck.authorName[0].toUpperCase() : 'U',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.deck.authorName,
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'PRO',
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '• ${widget.deck.totalCards > 0 ? widget.deck.totalCards : _cards.length} thuật ngữ',
                        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Mode Selection Tiles
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _buildModeTile(
                    icon: Icons.style_outlined,
                    iconColor: const Color(0xFF4A90E2),
                    iconBgColor: const Color(0xFF1E2840),
                    title: 'Thẻ ghi nhớ',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FlashcardFlipScreen(deck: widget.deck),
                        ),
                      );
                    },
                  ),
                  _buildModeTile(
                    icon: Icons.sync_alt,
                    iconColor: const Color(0xFF00C7B1),
                    iconBgColor: const Color(0xFF143034),
                    title: 'Trắc nghiệm',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FlashcardQuizScreen(deck: widget.deck),
                        ),
                      );
                    },
                  ),
                  _buildModeTile(
                    icon: Icons.edit_note,
                    iconColor: const Color(0xFF5E81F4),
                    iconBgColor: const Color(0xFF1D2444),
                    title: 'Tự luận',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FlashcardTypingScreen(deck: widget.deck),
                        ),
                      );
                    },
                  ),
                  _buildModeTile(
                    icon: Icons.layers_outlined,
                    iconColor: const Color(0xFF8B6BF6),
                    iconBgColor: const Color(0xFF282148),
                    title: 'Ghép thẻ',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FlashcardMatchingScreen(deck: widget.deck),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
