import 'package:flutter/material.dart';
import '../../../../core/theme/app_palette.dart';

class SegmentedProgressBar extends StatelessWidget {
  final int currentIndex;
  final int totalCount;
  final int segmentCount;

  const SegmentedProgressBar({
    super.key,
    required this.currentIndex,
    required this.totalCount,
    this.segmentCount = 5,
  });

  @override
  Widget build(BuildContext context) {
    double progress = totalCount > 0 ? (currentIndex / totalCount).clamp(0.0, 1.0) : 0.0;
    int activeSegments = (progress * segmentCount).ceil().clamp(1, segmentCount);

    return Row(
      children: [
        // Current index pill
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppPalette.surface,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          alignment: Alignment.center,
          child: Text(
            '$currentIndex',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Segment bars
        Expanded(
          child: Row(
            children: List.generate(segmentCount, (index) {
              bool isFilled = index < activeSegments;
              return Expanded(
                child: Container(
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                  decoration: BoxDecoration(
                    color: isFilled ? AppPalette.accent : AppPalette.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(width: 8),

        // Total count pill
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppPalette.surface,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          alignment: Alignment.center,
          child: Text(
            '$totalCount',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
