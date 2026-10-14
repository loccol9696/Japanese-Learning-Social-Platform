import 'package:flutter/material.dart';
import '../../data/models/flashcard_set_model.dart';
import '../../data/models/matching_game_model.dart';
import '../../data/services/flashcard_service.dart';
import '../widgets/segmented_progress_bar.dart';

class FlashcardMatchingScreen extends StatefulWidget {
  final FlashcardSetModel deck;

  const FlashcardMatchingScreen({super.key, required this.deck});

  @override
  State<FlashcardMatchingScreen> createState() => _FlashcardMatchingScreenState();
}

class _FlashcardMatchingScreenState extends State<FlashcardMatchingScreen> {
  final FlashcardService _service = FlashcardService.instance;

  MatchingGameModel? _game;
  bool _isLoading = true;
  MatchingTileModel? _firstSelected;
  final Set<String> _matchedTileIds = {};
  String? _wrongTileIdA;
  String? _wrongTileIdB;
  int _pairsFound = 0;

  @override
  void initState() {
    super.initState();
    _loadGame();
  }

  Future<void> _loadGame() async {
    setState(() => _isLoading = true);
    final game = await _service.getMatchingGame(widget.deck.setId);
    if (mounted) {
      setState(() {
        _game = game;
        _firstSelected = null;
        _matchedTileIds.clear();
        _wrongTileIdA = null;
        _wrongTileIdB = null;
        _pairsFound = 0;
        _isLoading = false;
      });
    }
  }

  void _onTileTap(MatchingTileModel tile) {
    if (_matchedTileIds.contains(tile.tileId)) return;
    if (_wrongTileIdA != null || _wrongTileIdB != null) return; // In wrong delay
    if (_firstSelected?.tileId == tile.tileId) {
      // Deselect
      setState(() => _firstSelected = null);
      return;
    }

    if (_firstSelected == null) {
      // Select first
      setState(() => _firstSelected = tile);
    } else {
      // Second tile selected
      final first = _firstSelected!;
      if (first.cardId == tile.cardId) {
        // MATCH!
        setState(() {
          _matchedTileIds.add(first.tileId);
          _matchedTileIds.add(tile.tileId);
          _firstSelected = null;
          _pairsFound++;
        });

        _service.submitAnswer(tile.cardId, true);

        if (_pairsFound >= (_game?.totalPairs ?? 5)) {
          _showWinDialog();
        }
      } else {
        // MISMATCH
        setState(() {
          _wrongTileIdA = first.tileId;
          _wrongTileIdB = tile.tileId;
          _firstSelected = null;
        });

        _service.submitAnswer(tile.cardId, false);

        Future.delayed(const Duration(milliseconds: 650), () {
          if (!mounted) return;
          setState(() {
            _wrongTileIdA = null;
            _wrongTileIdB = null;
          });
        });
      }
    }
  }

  void _showWinDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161922),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Chúc mừng!', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Bạn đã ghép đôi chính xác tất cả các thẻ!',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _loadGame();
            },
            child: const Text('Chơi lại', style: TextStyle(color: Color(0xFFFF2D55))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF2D55)),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Hoàn tất', style: TextStyle(color: Colors.white)),
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

    final tiles = _game?.tiles ?? [];

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
                        currentIndex: _pairsFound,
                        totalCount: _game?.totalPairs ?? 5,
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

            const SizedBox(height: 16),

            // 2x5 Grid (Screenshot 210635)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 2.1,
                  ),
                  itemCount: tiles.length,
                  itemBuilder: (context, index) {
                    final tile = tiles[index];
                    final isMatched = _matchedTileIds.contains(tile.tileId);
                    final isSelected = _firstSelected?.tileId == tile.tileId;
                    final isWrong = tile.tileId == _wrongTileIdA || tile.tileId == _wrongTileIdB;

                    if (isMatched) {
                      return const SizedBox.shrink(); // Hide matched tile
                    }

                    Color bgColor = const Color(0xFF161922);
                    Color borderColor = Colors.white.withOpacity(0.08);

                    if (isSelected) {
                      borderColor = const Color(0xFFFF2D55);
                    } else if (isWrong) {
                      borderColor = const Color(0xFFFF453A);
                      bgColor = const Color(0xFF38151D);
                    }

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _onTileTap(tile),
                        borderRadius: BorderRadius.circular(16),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: borderColor,
                              width: isSelected || isWrong ? 2.0 : 1.0,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFFFF2D55).withOpacity(0.3),
                                      blurRadius: 10,
                                      spreadRadius: 1,
                                    )
                                  ]
                                : null,
                          ),
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            tile.text,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: tile.type == 'TERM' ? 19 : 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Hint: "Chạm 2 thẻ tương ứng để ghép đôi"
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Text(
                'Chạm 2 thẻ tương ứng để ghép đôi',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
