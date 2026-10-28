import 'package:flutter/material.dart';
import '../../../../core/theme/app_palette.dart';
import 'streak_progress_bar.dart';

class LearningHeader extends StatelessWidget {
  final int currentIndex;
  final int totalItems;
  final VoidCallback onClose;
  final VoidCallback? onSettingsClick;
  /// Số câu đúng liên tiếp; từ 2 trở lên thanh tiến trình đổi màu và hiện ngọn lửa kèm số.
  final int streak;
  final double height;
  final EdgeInsetsGeometry progressPadding;

  const LearningHeader({
    super.key,
    required this.currentIndex,
    required this.totalItems,
    required this.onClose,
    this.onSettingsClick,
    this.streak = 0,
    this.height = 8,
    this.progressPadding = const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
  });

  @override
  Widget build(BuildContext context) {
    final validTotal = totalItems > 0 ? totalItems : 1;
    final clampedIndex = currentIndex.clamp(0, validTotal);
    final progress = totalItems > 0 ? (clampedIndex / validTotal).clamp(0.0, 1.0) : 0.0;
    final displayIndex = totalItems > 0 ? clampedIndex : 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Bar: Close (Left), Centered Counter (Middle), Settings (Right)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(Icons.close, color: AppPalette.textPrimary),
                onPressed: onClose,
                splashRadius: 22,
              ),
              Text(
                '$displayIndex / $totalItems',
                style: TextStyle(
                  color: AppPalette.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              if (onSettingsClick != null)
                IconButton(
                  icon: Icon(Icons.settings, color: AppPalette.textPrimary),
                  onPressed: onSettingsClick,
                  splashRadius: 22,
                )
              else
                const SizedBox(width: 48, height: 48),
            ],
          ),
        ),

        // Thanh tiến trình: đổi màu cam + ngọn lửa khi đúng liên tiếp
        Padding(
          padding: progressPadding,
          child: StreakProgressBar(progress: progress, streak: streak, height: height),
        ),
      ],
    );
  }
}
