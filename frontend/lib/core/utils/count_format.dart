/// Rút gọn số đếm: 950 -> "950", 8400 -> "8,4K", 12000 -> "12K", 1200000 -> "1,2M".
String formatCompactCount(int value) {
  if (value < 1000) return '$value';
  final isMillion = value >= 1000000;
  final scaled = value / (isMillion ? 1000000 : 1000);
  final suffix = isMillion ? 'M' : 'K';
  if (scaled >= 100) return '${scaled.round()}$suffix';
  final text = scaled.toStringAsFixed(1);
  final trimmed = text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
  return '${trimmed.replaceAll('.', ',')}$suffix';
}
