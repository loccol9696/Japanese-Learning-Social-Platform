/// Ngày không kèm giờ, để so sánh và làm khoá.
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Các ô của lịch tháng, bắt đầu từ Chủ nhật, đủ các tuần trọn vẹn phủ kín tháng
/// (gồm vài ngày của tháng trước/sau để đủ hàng).
List<DateTime> monthGridDays(DateTime month) {
  final first = DateTime(month.year, month.month, 1);
  final last = DateTime(month.year, month.month + 1, 0);
  // DateTime.weekday: Thứ hai = 1 ... Chủ nhật = 7; số ngày lùi để về Chủ nhật.
  final leading = first.weekday % 7;
  final trailing = (7 - (last.weekday % 7) - 1) % 7;
  final start = DateTime(first.year, first.month, 1 - leading);
  final total = leading + last.day + trailing;
  return [for (var i = 0; i < total; i++) DateTime(start.year, start.month, start.day + i)];
}
