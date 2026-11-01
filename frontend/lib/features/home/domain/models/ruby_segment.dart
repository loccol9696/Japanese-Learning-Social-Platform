class RubySegment {
  final String kanji;
  final String furigana;

  const RubySegment({required this.kanji, required this.furigana});

  factory RubySegment.fromJson(Map<String, dynamic> json) {
    return RubySegment(
      kanji: json['kanji'] as String? ?? '',
      furigana: json['furigana'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'kanji': kanji, 'furigana': furigana};
  }
}

class GrammarPointInfo {
  final String pattern;
  final String matchedText;
  final String jlptLevel;
  final String meaning;
  final String explanation;

  const GrammarPointInfo({
    required this.pattern,
    required this.matchedText,
    required this.jlptLevel,
    required this.meaning,
    required this.explanation,
  });

  factory GrammarPointInfo.fromJson(Map<String, dynamic> json) {
    return GrammarPointInfo(
      pattern: json['pattern']?.toString() ?? '',
      matchedText: json['matchedText']?.toString() ?? '',
      jlptLevel: json['jlptLevel']?.toString() ?? '',
      meaning: json['meaning']?.toString() ?? '',
      explanation: json['explanation']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'pattern': pattern,
    'matchedText': matchedText,
    'jlptLevel': jlptLevel,
    'meaning': meaning,
    'explanation': explanation,
  };
}

class SubtitleCue {
  final Duration start;
  final Duration end;
  final String text;
  final String translation;
  final List<GrammarPointInfo> grammarPoints;

  const SubtitleCue({
    required this.start,
    required this.end,
    required this.text,
    required this.translation,
    this.grammarPoints = const [],
  });

  bool contains(Duration position) {
    return position >= start && position < end;
  }
}

/// Bộ nhận diện mẫu ngữ pháp thông dụng dùng khi video chưa có dữ liệu `grammarAnalysis` từ backend.
List<GrammarPointInfo> detectFallbackGrammarPoints(String text) {
  if (text.trim().isEmpty) return const [];
  const rules = <(String, String, String, String, String)>[
    (
      'なければなりません',
      '〜なければならない',
      'N4',
      'phải làm gì',
      'Diễn tả nghĩa vụ hoặc việc bắt buộc phải thực hiện.',
    ),
    (
      'なければならない',
      '〜なければならない',
      'N4',
      'phải làm gì',
      'Diễn tả nghĩa vụ hoặc việc bắt buộc phải thực hiện.',
    ),
    (
      'かもしれません',
      '〜かもしれない',
      'N4',
      'có lẽ, không chừng',
      'Diễn tả sự phỏng đoán với mức độ chắc chắn thấp.',
    ),
    (
      'かもしれない',
      '〜かもしれない',
      'N4',
      'có lẽ, không chừng',
      'Diễn tả sự phỏng đoán với mức độ chắc chắn thấp.',
    ),
    (
      'ことができ',
      '〜ことができる',
      'N4',
      'có thể làm gì',
      'V(từ điển) + ことができる: diễn tả khả năng thực hiện hành động.',
    ),
    (
      'ようになり',
      '〜ようになる',
      'N3',
      'trở nên (có thể) ...',
      'Diễn tả sự thay đổi trạng thái hoặc khả năng theo thời gian.',
    ),
    (
      'てください',
      '〜てください',
      'N5',
      'hãy (làm gì)',
      'V-て + ください: dùng để yêu cầu, đề nghị hoặc nhờ vả lịch sự.',
    ),
    (
      'ています',
      '〜ている',
      'N5',
      'đang làm / trạng thái',
      'V-て + いる: diễn tả hành động đang diễn ra hoặc trạng thái kết quả.',
    ),
    (
      'ている',
      '〜ている',
      'N5',
      'đang làm / trạng thái',
      'V-て + いる: diễn tả hành động đang diễn ra hoặc trạng thái kết quả.',
    ),
    (
      'ましょう',
      '〜ましょう',
      'N5',
      'cùng (làm gì) nào',
      'V(bỏ ます) + ましょう: dùng để rủ rê, đề nghị người nghe cùng thực hiện hành động.',
    ),
    (
      'のは',
      '〜のは',
      'N4',
      'việc ... là ...',
      'Danh từ hoá mệnh đề động từ/tính từ bằng の, kết hợp với trợ từ は để nhấn mạnh chủ đề.',
    ),
    (
      'だろう',
      '〜だろう',
      'N4',
      'chắc là..., đúng không?',
      'Dạng thông thường của でしょう, dùng để suy đoán hoặc tìm sự đồng tình của người nghe.',
    ),
    (
      'だろ',
      '〜だろ',
      'N4',
      'chắc là..., đúng không?',
      'Cách nói thân mật của だろう / でしょう, thường dùng để khẳng định hoặc hỏi xác nhận.',
    ),
    (
      'でしょう',
      '〜でしょう',
      'N4',
      'có lẽ, chắc là...',
      'Diễn tả sự suy đoán lịch sự hoặc hỏi xác nhận thông tin từ người nghe.',
    ),
    (
      'たいです',
      '〜たい',
      'N5',
      'muốn (làm gì)',
      'V(bỏ ます) + たい: diễn tả mong muốn của bản thân người nói.',
    ),
    (
      'たい',
      '〜たい',
      'N5',
      'muốn (làm gì)',
      'V(bỏ ます) + たい: diễn tả mong muốn của bản thân người nói.',
    ),
    (
      'ので',
      '〜ので',
      'N4',
      'vì, bởi vì',
      'Nêu nguyên nhân hoặc lý do một cách khách quan, nhẹ nhàng.',
    ),
    (
      'から',
      '〜から',
      'N5',
      'từ / vì',
      'Chỉ điểm bắt đầu về thời gian, không gian, trình tự ("từ...") hoặc nêu lý do ("vì...").',
    ),
    (
      'ですか',
      '〜ですか',
      'N5',
      '... phải không?',
      'Mẫu câu nghi vấn lịch sự trong tiếng Nhật.',
    ),
  ];

  final points = <GrammarPointInfo>[];
  final seenPatterns = <String>{};
  for (final (keyword, pattern, level, meaning, explanation) in rules) {
    if (text.contains(keyword) && !seenPatterns.contains(pattern)) {
      seenPatterns.add(pattern);
      points.add(
        GrammarPointInfo(
          pattern: pattern,
          matchedText: keyword,
          jlptLevel: level,
          meaning: meaning,
          explanation: explanation,
        ),
      );
    }
  }
  return points;
}
