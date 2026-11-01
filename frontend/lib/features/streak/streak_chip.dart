import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import '../../core/widgets/flame_icon.dart';

/// Màu ngọn lửa của chuỗi học, cố định ở cả hai chế độ sáng/tối.
const Color streakFlameColor = Color(0xFFFF9F2E);

/// Màu số ngày vẽ trên ngọn lửa: tối đậm để dễ đọc trên nền cam ở cả hai chế độ sáng/tối.
const Color streakFlameNumberColor = Color(0xFF1A1033);

/// Viên thuốc "🔥 N" trên thanh icon của trang cá nhân; bấm để mở lịch chuỗi học.
/// Luôn hiện kể cả chuỗi bằng 0; ngọn lửa xám đi khi chưa có chuỗi.
class StreakChip extends StatelessWidget {
  const StreakChip({super.key, required this.days, this.onTap});

  final int days;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final flame = days > 0 ? streakFlameColor : AppPalette.textPrimary.withValues(alpha: 0.4);
    return Semantics(
      button: true,
      label: 'Chuỗi học $days ngày',
      child: Material(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FlameIcon(size: 18, color: flame),
                const SizedBox(width: 4),
                Text(
                  '$days',
                  style: TextStyle(
                    color: AppPalette.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
