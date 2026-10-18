import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../core/services/tts_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/flashcard_item_model.dart';

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
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isFront = true;
  bool _isPlayingAudio = false;
  Timer? _audioTimeoutTimer;

  bool get _termOnFront => widget.displayFrontFace == 'term';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(covariant DeckPreviewFlashcard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.card.cardId != widget.card.cardId) {
      _controller.reset();
      _isFront = true;
      _stopAudio();
    }
  }

  @override
  void dispose() {
    _stopAudio();
    _controller.dispose();
    super.dispose();
  }

  void _stopAudio() {
    _audioTimeoutTimer?.cancel();
    _audioTimeoutTimer = null;
    TtsService.stop();
    if (_isPlayingAudio && mounted) {
      setState(() => _isPlayingAudio = false);
    }
  }

  void _flip() {
    if (_isFront) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    setState(() => _isFront = !_isFront);
  }

  void _handlePlayAudio() {
    _audioTimeoutTimer?.cancel();

    // Đọc mặt đang hiển thị: thuật ngữ → tiếng Nhật, nghĩa → tiếng Việt.
    final speakTerm = _isFront == _termOnFront;
    final textToSpeak = speakTerm ? widget.card.term : widget.card.meaning;
    final lang = speakTerm ? 'ja-JP' : 'vi-VN';
    final rate = speakTerm ? 0.9 : 1.0;

    if (textToSpeak.trim().isEmpty) return;

    setState(() => _isPlayingAudio = true);

    // Fallback timer đề phòng sự kiện onend của Web Speech API bị trễ
    _audioTimeoutTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _isPlayingAudio) {
        setState(() => _isPlayingAudio = false);
      }
    });

    TtsService.speak(
      text: textToSpeak,
      lang: lang,
      rate: rate,
      onStart: () {
        if (mounted && !_isPlayingAudio) {
          setState(() => _isPlayingAudio = true);
        }
      },
      onComplete: () {
        _audioTimeoutTimer?.cancel();
        if (mounted) {
          setState(() => _isPlayingAudio = false);
        }
      },
    );
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
          _buildAudioButton(),
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

  Widget _buildAudioButton() {
    return Positioned(
      top: 4,
      left: 4,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handlePlayAudio,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _isPlayingAudio
                ? AppColors.flashCoral.withValues(alpha: 0.18)
                : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: _isPlayingAudio
                  ? AppColors.flashCoral.withValues(alpha: 0.5)
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: AnimatedScale(
            scale: _isPlayingAudio ? 1.2 : 1.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutBack,
            child: Icon(
              _isPlayingAudio
                  ? Icons.volume_up_rounded
                  : Icons.volume_up_outlined,
              color: _isPlayingAudio
                  ? AppColors.flashCoral
                  : Colors.white.withValues(alpha: 0.5),
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}
