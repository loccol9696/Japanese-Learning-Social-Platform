import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/services/tts_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/flashcard_item_model.dart';

/// Phát âm mặt thẻ bằng TTS và theo dõi trạng thái đang phát cho [CardAudioButton].
mixin CardAudioMixin<T extends StatefulWidget> on State<T> {
  bool isPlayingAudio = false;
  Timer? _audioTimeoutTimer;

  /// Đọc thuật ngữ (tiếng Nhật) nếu [speakTerm], ngược lại đọc nghĩa (tiếng Việt).
  void playCardAudio(FlashcardItemModel card, {required bool speakTerm}) {
    _audioTimeoutTimer?.cancel();

    final textToSpeak = speakTerm ? card.term : card.meaning;
    if (textToSpeak.trim().isEmpty) return;

    setState(() => isPlayingAudio = true);

    // Fallback timer đề phòng sự kiện onend của Web Speech API bị trễ
    _audioTimeoutTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && isPlayingAudio) {
        setState(() => isPlayingAudio = false);
      }
    });

    TtsService.speak(
      text: textToSpeak,
      lang: speakTerm ? 'ja-JP' : 'vi-VN',
      rate: speakTerm ? 0.9 : 1.0,
      onStart: () {
        if (mounted && !isPlayingAudio) {
          setState(() => isPlayingAudio = true);
        }
      },
      onComplete: () {
        _audioTimeoutTimer?.cancel();
        if (mounted) {
          setState(() => isPlayingAudio = false);
        }
      },
    );
  }

  void stopCardAudio() {
    _cancelAudio();
    if (isPlayingAudio && mounted) {
      setState(() => isPlayingAudio = false);
    }
  }

  void _cancelAudio() {
    _audioTimeoutTimer?.cancel();
    _audioTimeoutTimer = null;
    TtsService.stop();
  }

  @override
  void dispose() {
    // Không setState trong dispose: chỉ dừng TTS và timer.
    _cancelAudio();
    super.dispose();
  }
}

/// Nút loa ở góc trên trái của thẻ; phóng to và đổi màu khi đang phát.
class CardAudioButton extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onTap;
  final double inset;
  final double iconSize;
  final double idleAlpha;

  const CardAudioButton({
    super.key,
    required this.isPlaying,
    required this.onTap,
    this.inset = 4,
    this.iconSize = 22,
    this.idleAlpha = 0.5,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: inset,
      left: inset,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isPlaying
                ? AppColors.flashCoral.withValues(alpha: 0.18)
                : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: isPlaying
                  ? AppColors.flashCoral.withValues(alpha: 0.5)
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: AnimatedScale(
            scale: isPlaying ? 1.2 : 1.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutBack,
            child: Icon(
              isPlaying ? Icons.volume_up_rounded : Icons.volume_up_outlined,
              color: isPlaying
                  ? AppColors.flashCoral
                  : Colors.white.withValues(alpha: idleAlpha),
              size: iconSize,
            ),
          ),
        ),
      ),
    );
  }
}
