/// Số nguyên có dấu chấm ngăn cách hàng nghìn, kiểu Việt Nam: 3580 -> "3.580".
String formatTokenCount(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return value < 0 ? '-$buffer' : buffer.toString();
}

/// Token đã dùng trong một ngày.
class TokenDayUsage {
  final DateTime date;
  final int tokens;

  const TokenDayUsage({required this.date, required this.tokens});

  factory TokenDayUsage.fromJson(Map<String, dynamic> json) {
    final parsed = DateTime.tryParse(json['date']?.toString() ?? '');
    return TokenDayUsage(
      // Chỉ lấy ngày (giờ địa phương), bỏ giờ nếu server có gửi kèm.
      date: parsed == null ? DateTime(1970) : DateTime(parsed.year, parsed.month, parsed.day),
      tokens: (json['tokens'] as num?)?.toInt() ?? 0,
    );
  }

  /// Thứ trong tuần dạng ngắn: T2 ... T7, CN.
  String get weekdayShort => weekdayShortOf(date);

  /// Thứ trong tuần dạng đầy đủ: Thứ hai ... Chủ nhật.
  String get weekdayFull => weekdayFullOf(date);
}

String weekdayShortOf(DateTime date) =>
    const ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'][(date.weekday - 1).clamp(0, 6)];

String weekdayFullOf(DateTime date) => const [
      'Thứ hai',
      'Thứ ba',
      'Thứ tư',
      'Thứ năm',
      'Thứ sáu',
      'Thứ bảy',
      'Chủ nhật',
    ][(date.weekday - 1).clamp(0, 6)];

/// Token đã dùng cho một tính năng AI.
class TokenFeatureUsage {
  /// Mã tính năng do server gửi, ví dụ VIDEO_SUBTITLE.
  final String feature;
  final int tokens;

  const TokenFeatureUsage({required this.feature, required this.tokens});

  factory TokenFeatureUsage.fromJson(Map<String, dynamic> json) => TokenFeatureUsage(
        feature: json['feature']?.toString() ?? '',
        tokens: (json['tokens'] as num?)?.toInt() ?? 0,
      );

  /// Tên hiển thị. Mã chưa biết (server có thêm tính năng mới) thì hiện nguyên mã.
  String get label => switch (feature) {
        'VIDEO_SUBTITLE' => 'Tạo phụ đề tự động cho video',
        'GRAMMAR_ANALYSIS' => 'Phân tích ngữ pháp',
        _ => feature,
      };
}

/// Lịch sử dùng token AI trong một tuần ("week") hoặc một tháng ("month").
class TokenUsage {
  final String range;
  final int totalTokens;
  final List<TokenDayUsage> days;
  final List<TokenFeatureUsage> features;

  const TokenUsage({
    required this.range,
    required this.totalTokens,
    required this.days,
    required this.features,
  });

  factory TokenUsage.fromJson(Map<String, dynamic> json) {
    List<T> list<T>(String key, T Function(Map<String, dynamic>) parse) => (json[key] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(parse)
        .toList();

    return TokenUsage(
      range: json['range']?.toString() ?? 'week',
      totalTokens: (json['totalTokens'] as num?)?.toInt() ?? 0,
      days: list('days', TokenDayUsage.fromJson),
      features: list('features', TokenFeatureUsage.fromJson),
    );
  }

  bool get isMonth => range == 'month';
}
