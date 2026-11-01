/// Một từ của câu gốc kèm cờ đọc đúng / sai.
class ShadowingWord {
  final String text;
  final bool correct;

  const ShadowingWord({required this.text, required this.correct});

  factory ShadowingWord.fromJson(Map<String, dynamic> json) => ShadowingWord(
    text: json['text']?.toString() ?? '',
    correct: json['correct'] == true,
  );
}

/// Kết quả chấm một lượt luyện nói cho một dòng phụ đề.
class ShadowingLineScore {
  final int lineIndex;
  final String expectedText;
  final String recognizedText;
  final int score;

  /// EXCELLENT / GOOD / FAIR / TRY_AGAIN
  final String level;
  final List<ShadowingWord> words;
  final int bestScore;

  const ShadowingLineScore({
    required this.lineIndex,
    required this.expectedText,
    required this.recognizedText,
    required this.score,
    required this.level,
    required this.words,
    required this.bestScore,
  });

  factory ShadowingLineScore.fromJson(Map<String, dynamic> json) {
    final score = (json['score'] as num?)?.toInt() ?? 0;
    return ShadowingLineScore(
      lineIndex: (json['lineIndex'] as num?)?.toInt() ?? 0,
      expectedText: json['expectedText']?.toString() ?? '',
      recognizedText: json['recognizedText']?.toString() ?? '',
      score: score,
      level: json['level']?.toString() ?? 'TRY_AGAIN',
      words: ((json['words'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ShadowingWord.fromJson)
          .toList(),
      bestScore: (json['bestScore'] as num?)?.toInt() ?? score,
    );
  }
}

/// Điểm cao nhất từng dòng của người dùng cho một video.
class ShadowingSummary {
  /// lineIndex -> điểm cao nhất
  final Map<int, int> bestScores;
  final int averageScore;

  const ShadowingSummary({
    this.bestScores = const {},
    this.averageScore = 0,
  });

  factory ShadowingSummary.fromJson(Map<String, dynamic> json) {
    final best = <int, int>{};
    for (final line in ((json['lines'] as List?) ?? const [])) {
      if (line is Map<String, dynamic>) {
        best[(line['lineIndex'] as num).toInt()] =
            (line['bestScore'] as num).toInt();
      }
    }
    return ShadowingSummary(
      bestScores: best,
      averageScore: (json['averageScore'] as num?)?.toInt() ?? 0,
    );
  }
}
