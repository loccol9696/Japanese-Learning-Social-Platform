import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/flashcard_item_model.dart';
import 'card_audio.dart';

/// Thẻ xem trước trong carousel của màn bộ thẻ: chạm để lật 3D, nút phát âm, gắn sao.
class DeckPreviewFlashcard extends StatefulWidget {
  final FlashcardItemModel card;
  final String displayFrontFace; // 'term' or 'definition'
  final VoidCallback onToggleStar;

  const DeckPreviewFlashcard({
    super.key,
    required this.card,
    this.displayFrontFace = 'term',
    required this.onToggleStar,
  });

  @override
  State<DeckPreviewFlashcard> createState() => _DeckPreviewFlashcardState();
}

class _DeckPreviewFlashcardState extends State<DeckPreviewFlashcard>
    with SingleTickerProviderStateMixin, CardAudioMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isFront = true;

  bool get _termOnFront => widget.displayFrontFace == 'term';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(covariant DeckPreviewFlashcard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.card.cardId != widget.card.cardId) {
      _controller.reset();
      _isFront = true;
      stopCardAudio();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _flip() {
    if (_isFront) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    setState(() => _isFront = !_isFront);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _flip,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final angle = _animation.value * pi;
          final isFrontVisible = angle <= (pi / 2);

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001) // 3D perspective
              ..rotateY(angle),
            child: isFrontVisible
                ? _buildFront()
                : Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(pi),
                    child: _buildBack(),
                  ),
          );
        },
      ),
    );
  }

  Widget _buildFront() {
    return _buildFace(
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _termOnFront ? widget.card.term : widget.card.meaning,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: _termOnFront ? 40 : 26,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBack() {
    final reading = widget.card.reading;
    return _buildFace(
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (reading != null && reading.isNotEmpty) ...[
              Text(
                reading,
                style: const TextStyle(
                  color: AppColors.flashReading,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
            ],
            Text(
              _termOnFront ? widget.card.meaning : widget.card.term,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: _termOnFront ? 24 : 38,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Khung chung của 2 mặt thẻ: nền đặc, nút phát âm (trái), nút sao (phải), nội dung giữa.
  Widget _buildFace(Widget content) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.socialSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.flashBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          CardAudioButton(
            isPlaying: isPlayingAudio,
            // Đọc mặt đang hiển thị: thuật ngữ → tiếng Nhật, nghĩa → tiếng Việt.
            onTap: () =>
                playCardAudio(widget.card, speakTerm: _isFront == _termOnFront),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              icon: Icon(
                widget.card.isStarred
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
                color: widget.card.isStarred
                    ? AppColors.flashStar
                    : Colors.white.withValues(alpha: 0.4),
                size: 24,
              ),
              onPressed: widget.onToggleStar,
              splashRadius: 20,
            ),
          ),
          Center(child: content),
        ],
      ),
    );
  }
}
