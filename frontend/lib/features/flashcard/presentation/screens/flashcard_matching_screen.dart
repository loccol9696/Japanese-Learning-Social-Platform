import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../data/models/flashcard_set_model.dart';
import '../../data/models/matching_game_model.dart';
import '../../data/services/flashcard_service.dart';
import '../widgets/answer_streak.dart';
import '../widgets/completion_fireworks.dart';
import '../widgets/fire_celebration.dart';
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
  List<MatchingGameModel> _rounds = [];
  int _currentRoundIndex = 0;
  int _completedPairs = 0;
  int _totalPairs = 0;
  bool _isLoading = true;
  MatchingTileModel? _firstSelected;
  final Set<String> _matchedTileIds = {};
  String? _wrongTileIdA;
  String? _wrongTileIdB;
  int _pairsFound = 0;
  final AnswerStreak _streak = AnswerStreak();
  int _fireTrigger = 0;

  /// Số ván đã nạp; dùng để bỏ qua các hẹn giờ của ván cũ và dựng lại lưới khi chơi lại.
  int _gameSerial = 0;

  /// Lưới 2 cột. Cột cố định theo thứ tự thẻ; hàng đổi khi thẻ phía dưới biến mất và thẻ phía trên rơi xuống.
  static const int _columns = 2;
  static const int _pairsPerRound = 5;
  static const double _gap = 10;
  static const double _aspectRatio = 1.08;
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
    _streak.reset();
    setState(() => _isLoading = true);
    final requestedPairs = widget.deck.totalCards > 0 ? widget.deck.totalCards : 20;
    final fullGame = await _service.getMatchingGame(
      widget.deck.setId,
      pairCount: requestedPairs,
    );
    if (mounted) {
      setState(() {
        _rounds = _buildRounds(fullGame);
        _currentRoundIndex = 0;
        _completedPairs = 0;
        _totalPairs = fullGame.totalPairs;
        _activateRound(0);
        _isLoading = false;
      });
    }
  }

  List<MatchingGameModel> _buildRounds(MatchingGameModel fullGame) {
    if (fullGame.totalPairs <= _pairsPerRound) {
      return [fullGame];
    }
    final pairs = <int, List<MatchingTileModel>>{};
    for (final tile in fullGame.tiles) {
      pairs.putIfAbsent(tile.cardId, () => []).add(tile);
    }
    final groupedPairs = pairs.values.where((pair) => pair.length >= 2).toList()..shuffle();
    final rounds = <MatchingGameModel>[];
    for (var start = 0; start < groupedPairs.length; start += _pairsPerRound) {
      final end = math.min(start + _pairsPerRound, groupedPairs.length);
      final tiles = groupedPairs.sublist(start, end).expand((pair) => pair).toList()..shuffle();
      rounds.add(MatchingGameModel(
        setId: fullGame.setId,
        totalPairs: end - start,
        tiles: tiles,
      ));
    }
    return rounds;
  }

  void _activateRound(int index) {
    _game = _rounds.isEmpty ? null : _rounds[index];
    _firstSelected = null;
    _matchedTileIds.clear();
    _wrongTileIdA = null;
    _wrongTileIdB = null;
    _pairsFound = 0;
    _gameSerial++;
    _placeTiles(_game?.tiles ?? const <MatchingTileModel>[]);
  }

  void _finishRound(int serial) {
    if (!mounted || serial != _gameSerial) return;
    if (_currentRoundIndex < _rounds.length - 1) {
      setState(() {
        _completedPairs += _game?.totalPairs ?? 0;
        _currentRoundIndex++;
        _activateRound(_currentRoundIndex);
      });
    } else {
      _showWinDialog();
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
        final reachedFireMilestone = _streak.record(correct: true);
        setState(() {
          _matchedTileIds.add(first.tileId);
          _matchedTileIds.add(tile.tileId);
          _firstSelected = null;
          _pairsFound++;
          if (reachedFireMilestone) _fireTrigger++;
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
          final celebrationDelay = reachedFireMilestone
              ? const Duration(milliseconds: 1900)
              : const Duration(milliseconds: 250);
          Future.delayed(_popDuration + celebrationDelay, () {
            if (!mounted || serial != _gameSerial) return;
            _finishRound(serial);
          });
        }
      } else {
        // MISMATCH
        _streak.record(correct: false);
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
      builder: (ctx) => Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          const IgnorePointer(child: CompletionFireworks()),
          Center(
            child: AlertDialog(
              backgroundColor: AppPalette.background,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text('Chúc mừng!', style: TextStyle(color: AppPalette.textPrimary)),
              content: Text(
                'Bạn đã ghép đôi chính xác tất cả các thẻ!',
                style: TextStyle(color: AppPalette.textSecondary),
              ),
              actions: [
                TextButton(
                  key: const ValueKey('matching-restart'),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _loadGame();
                  },
                  child: Text('Học lại', style: TextStyle(color: AppPalette.textPrimary)),
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
          ),
        ],
      ),
    );
  }

  Widget _buildTile(MatchingTileModel tile) {
    final isMatched = _matchedTileIds.contains(tile.tileId);
    final isSelected = _firstSelected?.tileId == tile.tileId;
    final isWrong = tile.tileId == _wrongTileIdA || tile.tileId == _wrongTileIdB;

    Color bgColor = AppPalette.surface;
    Color borderColor = AppPalette.textPrimary.withValues(alpha: 0.10);

    if (isSelected) {
      borderColor = AppPalette.accent;
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
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: borderColor,
                    width: isSelected || isWrong ? 1.5 : 1.0,
                  ),
                ),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(
                  tile.text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppPalette.textPrimary,
                    fontSize: tile.type == 'TERM' ? 17 : 15,
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
      body: Stack(
        fit: StackFit.expand,
        children: [
          SafeArea(
            child: Column(
              children: [
            // Top Bar & Continuous Progress Bar
            LearningHeader(
              currentIndex: _completedPairs + _pairsFound,
              totalItems: _totalPairs,
              streak: _streak.count,
              onClose: () => Navigator.pop(context),
            ),

            const SizedBox(height: 8),

            // Lưới 2 cột; thẻ ghép đúng biến mất và các thẻ phía trên rơi xuống lấp chỗ trống.
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final tileWidth = (constraints.maxWidth - _gap * (_columns - 1)) / _columns;
                    final rows = (tiles.length + _columns - 1) ~/ _columns;
                    final heightFromWidth = tileWidth / _aspectRatio;
                    final heightFromSpace = rows == 0
                        ? 0.0
                        : math.max(0.0, (constraints.maxHeight - _gap * (rows - 1)) / rows);
                    final tileHeight = math.min(heightFromWidth, heightFromSpace);
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
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              child: Text(
                'Chạm 2 thẻ tương ứng để ghép đôi',
                style: TextStyle(
                  color: AppPalette.textPrimary.withValues(alpha: 0.4),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
              ],
            ),
          ),
          FireCelebration(trigger: _fireTrigger, streak: _streak.count),
        ],
      ),
    );
  }
}
