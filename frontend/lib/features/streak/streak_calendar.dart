/// Ngày không kèm giờ, để so sánh và làm khoá.
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Số hàng (tuần) của lưới lịch. Luôn 6 hàng để bảng không đổi chiều cao khi chuyển giữa các tháng
/// (tháng có 4, 5 hay 6 tuần), ngày thừa của tháng trước / sau được hiện mờ.
const int calendarWeeks = 6;

/// Các ô của lịch tháng: bắt đầu từ Chủ nhật, luôn đủ [calendarWeeks] tuần (42 ô).
List<DateTime> monthGridDays(DateTime month) {
  final first = DateTime(month.year, month.month, 1);
  // DateTime.weekday: Thứ hai = 1 ... Chủ nhật = 7; số ngày lùi để về Chủ nhật.
  final leading = first.weekday % 7;
  final start = DateTime(first.year, first.month, 1 - leading);
  return [
    for (var i = 0; i < calendarWeeks * 7; i++) DateTime(start.year, start.month, start.day + i),
  ];
}
