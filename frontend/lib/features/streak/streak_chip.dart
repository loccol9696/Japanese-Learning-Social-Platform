import 'package:flutter/material.dart';

import '../../core/localization/locale_manager.dart';
import '../../core/theme/app_palette.dart';

/// Viên thuốc nhỏ hiện số ngày học liên tục. Mờ đi khi hôm nay chưa học (streak sắp đứt).
class StreakChip extends StatelessWidget {
  const StreakChip({super.key, required this.days, this.activeToday = true});

  final int days;
  final bool activeToday;

  @override
  Widget build(BuildContext context) {
    final color = activeToday ? AppPalette.gold : AppPalette.textPrimary.withValues(alpha: 0.45);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department_rounded, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            appStrings.dayStreak(days),
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
