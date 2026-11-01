import 'package:flutter/material.dart';
import '../../data/models/flashcard_set_model.dart';
import '../../data/models/matching_game_model.dart';
import '../../data/services/flashcard_service.dart';
import '../widgets/learning_header.dart';
import '../../../../core/theme/app_palette.dart';

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

  /// Số ván đã nạp; dùng để bỏ qua các hẹn giờ của ván cũ và dựng lại lưới khi chơi lại.
  int _gameSerial = 0;

  /// Lưới 2 cột. Cột cố định theo thứ tự thẻ; hàng đổi khi thẻ phía dưới biến mất và thẻ phía trên rơi xuống.
  static const int _columns = 2;
  static const double _gap = 12;
  static const double _aspectRatio = 2.1;
  final Map<String, int> _colOf = {};
  final Map<String, int> _rowOf = {};

  /// Thời gian thẻ ghép đúng thu nhỏ rồi biến mất, sau đó các thẻ phía trên mới rơi.
  static const Duration _popDuration = Duration(milliseconds: 200);
  static const Duration _fallDuration = Duration(milliseconds: 450);

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
        _gameSerial++;
        _placeTiles(game.tiles);
        _isLoading = false;
      });
    }
  }

  /// Xếp thẻ vào lưới theo thứ tự nhận từ server: lần lượt trái, phải, trái, phải...
  void _placeTiles(List<MatchingTileModel> tiles) {
    _colOf.clear();
    _rowOf.clear();
    for (var i = 0; i < tiles.length; i++) {
      _colOf[tiles[i].tileId] = i % _columns;
      _rowOf[tiles[i].tileId] = i ~/ _columns;
    }
  }

  /// Trọng lực kiểu Candy Crush: trong mỗi cột, các thẻ còn lại dồn xuống đáy, chỗ trống dồn lên trên.
  void _applyGravity() {
    final tiles = _game?.tiles ?? const <MatchingTileModel>[];
    final rows = (tiles.length + _columns - 1) ~/ _columns;
    for (var col = 0; col < _columns; col++) {
      final remaining = tiles
          .where((t) => _colOf[t.tileId] == col && !_matchedTileIds.contains(t.tileId))
          .toList()
        ..sort((a, b) => _rowOf[a.tileId]!.compareTo(_rowOf[b.tileId]!));
      final firstRow = rows - remaining.length;
      for (var k = 0; k < remaining.length; k++) {
        _rowOf[remaining[k].tileId] = firstRow + k;
      }
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

        final serial = _gameSerial;
        // Đợi thẻ thu nhỏ xong rồi các thẻ phía trên mới rơi xuống lấp chỗ trống.
        Future.delayed(_popDuration, () {
          if (!mounted || serial != _gameSerial) return;
          setState(_applyGravity);
        });

        if (_pairsFound >= (_game?.totalPairs ?? 5)) {
          // Để người chơi thấy cặp cuối biến mất rồi mới hiện hộp chúc mừng.
          Future.delayed(_popDuration + const Duration(milliseconds: 250), () {
            if (!mounted || serial != _gameSerial) return;
            _showWinDialog();
          });
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
        backgroundColor: AppPalette.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Chúc mừng!', style: TextStyle(color: AppPalette.textPrimary)),
        content: Text(
          'Bạn đã ghép đôi chính xác tất cả các thẻ!',
          style: TextStyle(color: AppPalette.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _loadGame();
            },
            child: Text('Chơi lại', style: TextStyle(color: AppPalette.accent)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppPalette.accent),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: Text('Hoàn tất', style: TextStyle(color: AppPalette.onAccent)),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(MatchingTileModel tile) {
    final isMatched = _matchedTileIds.contains(tile.tileId);
    final isSelected = _firstSelected?.tileId == tile.tileId;
    final isWrong = tile.tileId == _wrongTileIdA || tile.tileId == _wrongTileIdB;

    Color bgColor = AppPalette.background;
    Color borderColor = AppPalette.textPrimary.withValues(alpha: 0.08);

    if (isSelected) {
      borderColor = AppPalette.error;
    } else if (isWrong) {
      borderColor = AppPalette.error;
      bgColor = AppPalette.errorContainer;
    }

    return IgnorePointer(
      ignoring: isMatched,
      child: AnimatedScale(
        scale: isMatched ? 0.0 : 1.0,
        duration: _popDuration,
        curve: Curves.easeIn,
        child: AnimatedOpacity(
          opacity: isMatched ? 0.0 : 1.0,
          duration: _popDuration,
          child: Material(
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
                            color: AppPalette.error.withValues(alpha: 0.3),
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
                    color: AppPalette.textPrimary,
                    fontSize: tile.type == 'TERM' ? 19 : 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
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

    final tiles = _game?.tiles ?? [];

    return Scaffold(
      backgroundColor: AppPalette.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar & Continuous Progress Bar
            LearningHeader(
              currentIndex: _pairsFound,
              totalItems: _game?.totalPairs ?? 5,
              onClose: () => Navigator.pop(context),
              onSettingsClick: () {},
            ),

            const SizedBox(height: 16),

            // Lưới 2 cột; thẻ ghép đúng biến mất và các thẻ phía trên rơi xuống lấp chỗ trống.
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final tileWidth = (constraints.maxWidth - _gap * (_columns - 1)) / _columns;
                    final tileHeight = tileWidth / _aspectRatio;
                    final rows = (tiles.length + _columns - 1) ~/ _columns;
                    final boardHeight = rows == 0 ? 0.0 : rows * tileHeight + (rows - 1) * _gap;

                    return Align(
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        height: boardHeight,
                        child: Stack(
                          key: ValueKey('match-board-$_gameSerial'),
                          clipBehavior: Clip.none,
                          children: [
                            for (final tile in tiles)
                              AnimatedPositioned(
                                key: ValueKey('match-tile-${tile.tileId}'),
                                duration: _fallDuration,
                                curve: Curves.bounceOut,
                                left: (_colOf[tile.tileId] ?? 0) * (tileWidth + _gap),
                                top: (_rowOf[tile.tileId] ?? 0) * (tileHeight + _gap),
                                width: tileWidth,
                                height: tileHeight,
                                child: _buildTile(tile),
                              ),
                          ],
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
                  color: AppPalette.textPrimary.withValues(alpha: 0.4),
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
