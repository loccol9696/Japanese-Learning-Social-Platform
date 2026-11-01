/// Chuỗi ngày học liên tục của người dùng (khớp StreakResponse ở backend).
class Streak {
  final int currentStreak;
  final int longestStreak;

  /// Hôm nay đã học chưa; false khi [currentStreak] > 0 nghĩa là sắp đứt nếu hôm nay không học.
  final bool activeToday;

  const Streak({
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.activeToday = false,
  });

  bool get atRisk => currentStreak > 0 && !activeToday;

  factory Streak.fromJson(Map<String, dynamic> json) => Streak(
        currentStreak: (json['currentStreak'] as num?)?.toInt() ?? 0,
        longestStreak: (json['longestStreak'] as num?)?.toInt() ?? 0,
        activeToday: json['activeToday'] as bool? ?? false,
      );
}
