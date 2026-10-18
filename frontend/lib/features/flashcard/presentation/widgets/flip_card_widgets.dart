import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/flashcard_item_model.dart';

// Các khối giao diện của màn FlashcardFlipScreen.

/// Một mặt của thẻ học (trước hoặc sau), viền ánh màu theo hướng đang vuốt.
class FlipCardFace extends StatelessWidget {
  final FlashcardItemModel card;
  final bool isBack;
  final String displayFrontFace; // 'term' or 'definition'
  final Widget audioButton;
  final VoidCallback onToggleStar;
  final Color? glowColor;
  final double glowOpacity;

  /// Độ mờ nội dung (chỉ mặt trước; thẻ nằm dưới ẩn chữ khi chưa vuốt).
  final double contentOpacity;

  const FlipCardFace({
    super.key,
    required this.card,
    required this.isBack,
    required this.displayFrontFace,
    required this.audioButton,
    required this.onToggleStar,
    this.glowColor,
    this.glowOpacity = 0.0,
    this.contentOpacity = 1.0,
  });

  bool get _isFrontTerm => displayFrontFace == 'term';

  @override
  Widget build(BuildContext context) {
    const defaultBorder = AppColors.flashBorder;
    final borderColor = glowColor != null
        ? Color.lerp(defaultBorder, glowColor, glowOpacity.clamp(0.0, 1.0))!
        : defaultBorder;

    final stack = Stack(
      children: [
        audioButton,
        Positioned(
          top: 20,
          right: 20,
          child: IconButton(
            icon: Icon(
              card.isStarred ? Icons.star : Icons.star_border,
              color: card.isStarred
                  ? AppColors.flashStar
                  : Colors.white.withValues(alpha: 0.4),
              size: 26,
            ),
            onPressed: onToggleStar,
          ),
        ),
        Center(child: isBack ? _buildBackContent() : _buildFrontContent()),
      ],
    );

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.socialSurface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: borderColor,
          width: glowColor != null && glowOpacity > 0.15 ? 2.0 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: isBack ? stack : Opacity(opacity: contentOpacity, child: stack),
    );
  }

  Widget _buildFrontContent() {
    return Padding(
      padding: const EdgeInsets.all(28.0),
      child: Text(
        _isFrontTerm ? card.term : card.meaning,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontSize: _isFrontTerm ? 44 : 30,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildBackContent() {
    final reading = card.reading;
    final sinoVietnamese = card.sinoVietnamese;
    final example = card.example;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_isFrontTerm) ...[
            // Mặt trước hiển thị định nghĩa -> Mặt sau hiển thị to rõ thuật ngữ (term)
            Text(
              card.term,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 42,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (reading != null && reading.isNotEmpty)
            Text(
              reading,
              style: const TextStyle(
                color: AppColors.flashReading,
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
          const SizedBox(height: 8),
          if (sinoVietnamese != null && sinoVietnamese.isNotEmpty)
            Text(
              sinoVietnamese,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          if (_isFrontTerm) ...[
            const SizedBox(height: 12),
            Text(
              card.meaning,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (example != null && example.isNotEmpty) ...[
            const SizedBox(height: 20),
            Divider(color: Colors.white.withValues(alpha: 0.1)),
            const SizedBox(height: 12),
            Text(
              example,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Nhãn nghiêng "ĐÃ THUỘC" (góc trái, vuốt phải) / "CHƯA NHỚ" (góc phải, vuốt trái).
class SwipeVerdictBadge extends StatelessWidget {
  final bool known;
  final double opacity;

  const SwipeVerdictBadge({
    super.key,
    required this.known,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    final color = known ? AppColors.flashKnown : AppColors.flashUnknown;
    final background = known
        ? AppColors.flashKnownBg
        : AppColors.flashUnknownBg;

    return Positioned(
      top: 22,
      left: known ? 22 : null,
      right: known ? null : 22,
      child: Opacity(
        opacity: opacity,
        child: Transform.rotate(
          angle: (known ? -15 : 15) * pi / 180,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: background.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color, width: 2.2),
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 12),
              ],
            ),
            child: Text(
              known ? 'ĐÃ THUỘC' : 'CHƯA NHỚ',
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Hai nút "Chưa nhớ" / "Đã nhớ" dưới thẻ (tương đương vuốt trái / phải).
class FlipChoiceButtons extends StatelessWidget {
  final VoidCallback onUnknown;
  final VoidCallback onKnown;

  const FlipChoiceButtons({
    super.key,
    required this.onUnknown,
    required this.onKnown,
  });

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );
    const padding = EdgeInsets.symmetric(vertical: 14);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                shape: shape,
                padding: padding,
              ),
              onPressed: onUnknown,
              child: const Text(
                'Chưa nhớ',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.flashAccent,
                shape: shape,
                padding: padding,
              ),
              onPressed: onKnown,
              child: const Text(
                'Đã nhớ',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Hộp thoại kết thúc lượt ôn; "Trở về" đóng luôn màn học.
void showFlipCompleteDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.flashCardSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'Hoàn thành xuất sắc!',
        style: TextStyle(color: Colors.white),
      ),
      content: const Text(
        'Bạn đã hoàn thành lượt ôn tập cho bộ từ vựng này.',
        style: TextStyle(color: Colors.white70),
      ),
      actions: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.flashAccent,
          ),
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
