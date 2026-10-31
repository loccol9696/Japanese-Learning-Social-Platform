import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';
import '../../core/widgets/flame_icon.dart';
import 'streak_calendar.dart';
import 'streak_chip.dart';
import 'streak_model.dart';
import 'streak_service.dart';

/// Mở bảng "Chuỗi học" (số ngày liên tiếp + lịch tháng). [onLoaded] báo streak mới nhất để màn gọi cập nhật chip.
Future<void> showStreakSheet(
  BuildContext context, {
  required Streak streak,
  StreakService? service,
  ValueChanged<Streak>? onLoaded,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => StreakSheet(initial: streak, service: service, onLoaded: onLoaded),
  );
}

/// Chiều cao mỗi hàng của lịch tháng.
const double dayCellHeight = 38;

class StreakSheet extends StatefulWidget {
  const StreakSheet({super.key, required this.initial, this.service, this.onLoaded, this.today});

  final Streak initial;
  final StreakService? service;
  final ValueChanged<Streak>? onLoaded;

  /// Cho test cố định "hôm nay".
  final DateTime? today;

  @override
  State<StreakSheet> createState() => _StreakSheetState();
}

class _StreakSheetState extends State<StreakSheet> {
  static const _weekdays = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];

  late final StreakService _service = widget.service ?? StreakService();
  late final DateTime _today = dateOnly(widget.today ?? DateTime.now());
  late DateTime _month = DateTime(_today.year, _today.month);
  late Streak _streak = widget.initial;
  Set<DateTime> _days = {};
  int _loadToken = 0;

  @override
  void initState() {
    super.initState();
    _refreshStreak();
    _loadDays();
  }

  Future<void> _refreshStreak() async {
    try {
      final fresh = await _service.getMine();
      if (!mounted) return;
      setState(() => _streak = fresh);
      widget.onLoaded?.call(fresh);
    } catch (_) {
      // Giữ số đang có.
    }
  }

  Future<void> _loadDays() async {
    final grid = monthGridDays(_month);
    final token = ++_loadToken;
    try {
      final days = await _service.getDays(grid.first, grid.last);
      if (mounted && token == _loadToken) setState(() => _days = days);
    } catch (_) {
      // Lịch trống nếu không tải được; không chặn việc xem số chuỗi.
    }
  }

  bool get _isCurrentMonth => _month.year == _today.year && _month.month == _today.month;

  void _shiftMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      _days = {};
    });
    _loadDays();
  }

  @override
  Widget build(BuildContext context) {
    final grid = monthGridDays(_month);
    return Material(
      color: AppPalette.navBar,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        // Cuộn được để màn thấp vẫn xem hết lịch 6 hàng mà không tràn.
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppPalette.textPrimary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text(
                    'Chuỗi học',
                    style: TextStyle(
                      color: AppPalette.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: Icon(Icons.close_rounded, color: AppPalette.textPrimary),
                    tooltip: 'Đóng',
                  ),
                ],
              ),
              const SizedBox(height: 4),
              FlameIcon(
                size: 56,
                color: _streak.currentStreak > 0
                    ? streakFlameColor
                    : AppPalette.textPrimary.withValues(alpha: 0.3),
              ),
              Text(
                '${_streak.currentStreak}',
                key: const ValueKey('streak-count'),
                style: TextStyle(
                  color: AppPalette.textPrimary,
                  fontSize: 44,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'ngày liên tiếp · học mỗi ngày để giữ chuỗi',
                style: TextStyle(
                  color: AppPalette.textPrimary.withValues(alpha: 0.6),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 18),
              _buildMonthHeader(),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (final label in _weekdays)
                    Expanded(
                      child: Center(
                        child: Text(
                          label,
                          style: TextStyle(
                            color: AppPalette.textPrimary.withValues(alpha: 0.55),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              // Chiều cao hàng cố định (không theo chiều rộng màn) để lịch 6 hàng luôn gọn dù màn rộng.
              GridView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisExtent: dayCellHeight,
                ),
                children: [for (final day in grid) _buildDay(day)],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMonthHeader() {
    return Row(
      children: [
        Text(
          'tháng ${_month.month} năm ${_month.year}',
          key: const ValueKey('streak-month'),
          style: TextStyle(
            color: AppPalette.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const Spacer(),
        _MonthButton(
          key: const ValueKey('streak-prev'),
          icon: Icons.chevron_left_rounded,
          onTap: () => _shiftMonth(-1),
        ),
        const SizedBox(width: 8),
        _MonthButton(
          key: const ValueKey('streak-next'),
          icon: Icons.chevron_right_rounded,
          onTap: _isCurrentMonth ? null : () => _shiftMonth(1),
        ),
      ],
    );
  }

  Widget _buildDay(DateTime day) {
    final inMonth = day.month == _month.month;
    final active = _days.contains(day);
    final future = day.isAfter(_today);
    final textColor = AppPalette.textPrimary.withValues(alpha: inMonth ? 1 : 0.35);

    if (active) {
      final flame = inMonth ? streakFlameColor : streakFlameColor.withValues(alpha: 0.4);
      return Stack(
        key: ValueKey('streak-day-active-${day.year}-${day.month}-${day.day}'),
        alignment: Alignment.center,
        children: [
          FlameIcon(size: dayCellHeight, color: flame),
          Padding(
            // Số nằm trong thân tròn của ngọn lửa (phần dưới), không ở giữa hộp bao.
            padding: const EdgeInsets.only(top: 14),
            child: Text(
              '${day.day}',
              style: const TextStyle(
                color: streakFlameNumberColor,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
          ),
        ],
      );
    }
    return Center(
      child: Text(
        '${day.day}',
        style: TextStyle(
          color: future ? textColor : textColor.withValues(alpha: inMonth ? 0.7 : 0.3),
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MonthButton extends StatelessWidget {
  const _MonthButton({super.key, required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppPalette.textPrimary.withValues(alpha: enabled ? 0.3 : 0.12)),
        ),
        child: Icon(
          icon,
          color: AppPalette.textPrimary.withValues(alpha: enabled ? 1 : 0.3),
        ),
      ),
    );
  }
}
