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
