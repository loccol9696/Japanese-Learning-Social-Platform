class QuizQuestionModel {
  final int cardId;
  final String term;
  final String? sinoVietnamese;
  final String meaning;
  final String correctAnswer;
  final List<String> options;

  QuizQuestionModel({
    required this.cardId,
    required this.term,
    this.sinoVietnamese,
    required this.meaning,
    required this.correctAnswer,
    required this.options,
  });

  QuizQuestionModel copyWith({
    int? cardId,
    String? term,
    String? sinoVietnamese,
    String? meaning,
    String? correctAnswer,
    List<String>? options,
  }) {
    return QuizQuestionModel(
      cardId: cardId ?? this.cardId,
      term: term ?? this.term,
      sinoVietnamese: sinoVietnamese ?? this.sinoVietnamese,
      meaning: meaning ?? this.meaning,
      correctAnswer: correctAnswer ?? this.correctAnswer,
      options: options ?? this.options,
    );
  }

  factory QuizQuestionModel.fromJson(Map<String, dynamic> json) {
    return QuizQuestionModel(
      cardId: json['cardId'] as int? ?? 0,
      term: json['term'] as String? ?? '',
      sinoVietnamese: json['sinoVietnamese'] as String?,
      meaning: json['meaning'] as String? ?? '',
      correctAnswer: json['correctAnswer'] as String? ?? '',
      options: (json['options'] as List? ?? []).map((e) => e.toString()).toList(),
    );
  }
}
