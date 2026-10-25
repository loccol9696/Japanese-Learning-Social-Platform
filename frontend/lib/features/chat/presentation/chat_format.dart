/// Định dạng thời gian cho giao diện chat (không phụ thuộc gói intl).
library;

String _two(int value) => value.toString().padLeft(2, '0');

String formatClock(DateTime time) => '${_two(time.hour)}:${_two(time.minute)}';

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Thời gian ngắn cho danh sách hội thoại: giờ nếu hôm nay, "Hôm qua", hoặc ngày/tháng.
String formatConversationTime(DateTime? time, {DateTime? now}) {
  if (time == null) return '';
  final today = now ?? DateTime.now();
  if (isSameDay(time, today)) return formatClock(time);
  if (isSameDay(time, today.subtract(const Duration(days: 1)))) {
    return 'Hôm qua';
  }
  if (time.year == today.year) return '${_two(time.day)}/${_two(time.month)}';
  return '${_two(time.day)}/${_two(time.month)}/${time.year}';
}

/// Nhãn ngăn cách ngày trong khung chat.
String formatDayLabel(DateTime time, {DateTime? now}) {
  final today = now ?? DateTime.now();
  if (isSameDay(time, today)) return 'Hôm nay';
  if (isSameDay(time, today.subtract(const Duration(days: 1)))) {
    return 'Hôm qua';
  }
  return '${_two(time.day)}/${_two(time.month)}/${time.year}';
}

/// mm:ss từ số mili giây (dùng cho mốc thời gian video).
String formatMillis(int millis) {
  final totalSeconds = millis ~/ 1000;
  return '${_two(totalSeconds ~/ 60)}:${_two(totalSeconds % 60)}';
}

/// mm:ss từ số giây (thời lượng video).
String formatSeconds(int seconds) => formatMillis(seconds * 1000);
