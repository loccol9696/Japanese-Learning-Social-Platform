class FlashcardItemModel {
  final int cardId;
  final int? setId;
  final String term;
  final String? reading;
  final String? sinoVietnamese;
  final String meaning;
  final String? example;
  final String? audioUrl;
  final bool isStarred;
  final int boxLevel;
  final int correctCount;
  final int incorrectCount;

  FlashcardItemModel({
    required this.cardId,
    this.setId,
    required this.term,
    this.reading,
    this.sinoVietnamese,
    required this.meaning,
    this.example,
    this.audioUrl,
    this.isStarred = false,
    this.boxLevel = 0,
    this.correctCount = 0,
    this.incorrectCount = 0,
  });

  factory FlashcardItemModel.fromJson(Map<String, dynamic> json) {
    return FlashcardItemModel(
      cardId: json['cardId'] as int? ?? 0,
      setId: json['setId'] as int?,
      term: json['term'] as String? ?? '',
      reading: json['reading'] as String?,
      sinoVietnamese: json['sinoVietnamese'] as String?,
      meaning: json['meaning'] as String? ?? '',
      example: json['example'] as String?,
      audioUrl: json['audioUrl'] as String?,
      isStarred: json['isStarred'] as bool? ?? false,
      boxLevel: json['boxLevel'] as int? ?? 0,
      correctCount: json['correctCount'] as int? ?? 0,
      incorrectCount: json['incorrectCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'cardId': cardId,
        'setId': setId,
        'term': term,
        'reading': reading,
        'sinoVietnamese': sinoVietnamese,
        'meaning': meaning,
        'example': example,
        'audioUrl': audioUrl,
        'isStarred': isStarred,
        'boxLevel': boxLevel,
        'correctCount': correctCount,
        'incorrectCount': incorrectCount,
      };

  FlashcardItemModel copyWith({
    bool? isStarred,
    int? boxLevel,
    int? correctCount,
    int? incorrectCount,
  }) {
    return FlashcardItemModel(
      cardId: cardId,
      setId: setId,
      term: term,
      reading: reading,
      sinoVietnamese: sinoVietnamese,
      meaning: meaning,
      example: example,
      audioUrl: audioUrl,
      isStarred: isStarred ?? this.isStarred,
      boxLevel: boxLevel ?? this.boxLevel,
      correctCount: correctCount ?? this.correctCount,
      incorrectCount: incorrectCount ?? this.incorrectCount,
    );
  }
}
