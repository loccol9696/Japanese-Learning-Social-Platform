import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/flame_icon.dart';
import 'answer_streak.dart';

/// Thanh tiến trình của phiên luyện tập. Bình thường là màu nhấn; khi trả lời đúng liên tiếp
/// ([AnswerStreak.highlightFrom] câu trở lên) thì đổi sang màu cam và hiện ngọn lửa mang số chuỗi ở đầu thanh.
class StreakProgressBar extends StatelessWidget {
  const StreakProgressBar({
    super.key,
    required this.progress,
    this.streak = 0,
    this.height = 8,
  });

  /// 0..1
  final double progress;

  /// Số câu đúng liên tiếp.
  final int streak;
  final double height;

  static const Color _flameStart = Color(0xFFFFB347);
  static const Color _flameEnd = Color(0xFFFF7A18);
  static const double _badgeSize = 30;

  bool get _highlighted => streak >= AnswerStreak.highlightFrom;

  @override
  Widget build(BuildContext context) {
    final value = progress.clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: value, end: value),
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          builder: (context, animated, _) {
            final fillWidth = width * animated;
            return SizedBox(
              height: height,
              width: width,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Đường nền
                  Container(
                    key: const ValueKey('progress-track'),
                    decoration: BoxDecoration(
                      color: AppPalette.border.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(height),
                    ),
                  ),
                  // Phần đã hoàn thành
                  AnimatedContainer(
                    key: ValueKey(_highlighted ? 'progress-fill-fire' : 'progress-fill'),
                    duration: const Duration(milliseconds: 300),
                    width: fillWidth,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(height),
                      gradient: _highlighted
                          ? const LinearGradient(colors: [_flameStart, _flameEnd])
                          : null,
                      color: _highlighted ? null : AppPalette.accent.withValues(alpha: 0.55),
                    ),
                  ),
                  if (_highlighted) _buildBadge(fillWidth, width),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Ngọn lửa kèm số chuỗi, đặt ở đầu phần đã hoàn thành và không tràn ra ngoài thanh.
  Widget _buildBadge(double fillWidth, double width) {
    final left = (fillWidth - _badgeSize / 2).clamp(0.0, width - _badgeSize);
    return Positioned(
      left: left,
      top: height / 2 - _badgeSize / 2 - 4,
      child: Container(
        key: const ValueKey('streak-badge'),
        width: _badgeSize,
        height: _badgeSize,
        alignment: Alignment.center,
        child: Stack(
          alignment: Alignment.center,
          children: [
            const FlameIcon(size: _badgeSize, color: _flameStart),
            Padding(
              padding: const EdgeInsets.only(top: 9),
              child: Text(
                '$streak',
                style: const TextStyle(
                  color: Color(0xFF1A1033),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
