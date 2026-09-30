class RubySegment {
  final String kanji;
  final String furigana;

  const RubySegment({
    required this.kanji,
    required this.furigana,
  });

  factory RubySegment.fromJson(Map<String, dynamic> json) {
    return RubySegment(
      kanji: json['kanji'] as String? ?? '',
      furigana: json['furigana'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'kanji': kanji,
      'furigana': furigana,
    };
  }
}
