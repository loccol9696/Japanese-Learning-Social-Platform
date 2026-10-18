/// Định dạng số đếm kiểu mạng xã hội: 9.778 · 15,2K · 1,3M.
String formatCount(int value) {
  String oneDecimal(double v) {
    final text = v.toStringAsFixed(1);
    return (text.endsWith('.0') ? text.substring(0, text.length - 2) : text)
        .replaceAll('.', ',');
  }

  if (value >= 1000000) return '${oneDecimal(value / 1000000)}M';
  if (value >= 10000) return '${oneDecimal(value / 1000)}K';
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}
