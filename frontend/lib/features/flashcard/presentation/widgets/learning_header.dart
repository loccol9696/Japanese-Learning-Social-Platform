import 'package:flutter/material.dart';
import '../../../../core/theme/app_palette.dart';

class LearningHeader extends StatelessWidget {
  final int currentIndex;
  final int totalItems;
  final VoidCallback onClose;
  final VoidCallback? onSettingsClick;
  final Color? progressColor;
  final Color? trackColor;
  final double height;
  final EdgeInsetsGeometry progressPadding;

  const LearningHeader({
    super.key,
    required this.currentIndex,
    required this.totalItems,
    required this.onClose,
    this.onSettingsClick,
    this.progressColor,
    this.trackColor,
    this.height = 3.5,
    this.progressPadding = const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
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

        // Continuous Progress Bar
        Padding(
          padding: progressPadding,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: progress, end: progress),
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                return LinearProgressIndicator(
                  value: value,
                  minHeight: height,
                  backgroundColor: trackColor ?? AppPalette.border,
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor ?? AppPalette.accent),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
