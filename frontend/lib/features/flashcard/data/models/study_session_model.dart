import 'flashcard_item_model.dart';

/// Mức tự đánh giá khi ôn thẻ (khớp enum ReviewRating ở backend).
enum ReviewRating {
  again('AGAIN', 'Xem lại'),
  hard('HARD', 'Khó'),
  good('GOOD', 'Ổn'),
  easy('EASY', 'Dễ');

  final String apiName;
  final String label;
  const ReviewRating(this.apiName, this.label);

  /// Thẻ chỉ rời phiên học khi bấm "Dễ"; các mức còn lại phải lặp lại.
  bool get graduates => this == ReviewRating.easy;
}

/// Một thẻ trong phiên học ngắt quãng.
class StudyCard {
  final FlashcardItemModel card;

  /// NEW / LEARNING / REVIEW
  final String state;

  /// Nhãn thời gian dưới từng nút, theo [ReviewRating.apiName].
  final Map<String, String> intervalLabels;

  const StudyCard({
    required this.card,
    required this.state,
    required this.intervalLabels,
  });

  factory StudyCard.fromJson(Map<String, dynamic> json) {
    final labels = <String, String>{};
    final raw = json['intervalLabels'];
    if (raw is Map) {
      raw.forEach((k, v) => labels[k.toString()] = v.toString());
    }
    return StudyCard(
      card: FlashcardItemModel.fromJson(json['card'] as Map<String, dynamic>),
      state: json['state'] as String? ?? 'NEW',
      intervalLabels: labels,
    );
  }

  StudyCard withCard(FlashcardItemModel updated) =>
      StudyCard(card: updated, state: state, intervalLabels: intervalLabels);

  String labelFor(ReviewRating rating) =>
      intervalLabels[rating.apiName] ?? _fallbackLabels[rating]!;

  static const Map<ReviewRating, String> _fallbackLabels = {
    ReviewRating.again: '1 phút',
    ReviewRating.hard: '5 phút',
    ReviewRating.good: '10 phút',
    ReviewRating.easy: '4 ngày',
  };

  /// Nhãn trạng thái hiển thị trên thẻ.
  String get stateLabel => switch (state) {
    'LEARNING' => 'Đang học',
    'REVIEW' => 'Ôn tập',
    _ => 'Mới',
  };
}

class StudySession {
  final int setId;
  final List<StudyCard> cards;
  final int newCount;
  final int dueCount;

  const StudySession({
    required this.setId,
    required this.cards,
    required this.newCount,
    required this.dueCount,
  });

  factory StudySession.fromJson(Map<String, dynamic> json) {
    final list = (json['cards'] as List?) ?? const [];
    return StudySession(
      setId: json['setId'] as int? ?? 0,
      cards: list
          .map((e) => StudyCard.fromJson(e as Map<String, dynamic>))
          .toList(),
      newCount: json['newCount'] as int? ?? 0,
      dueCount: json['dueCount'] as int? ?? 0,
    );
  }
}

class ReviewResult {
  final bool graduated;
  final int intervalDays;
  final DateTime? nextReviewAt;

  const ReviewResult({
    required this.graduated,
    required this.intervalDays,
    this.nextReviewAt,
  });

  factory ReviewResult.fromJson(Map<String, dynamic> json) {
    final next = json['nextReviewAt'] as String?;
    return ReviewResult(
      graduated: json['graduated'] as bool? ?? false,
      intervalDays: json['intervalDays'] as int? ?? 0,
      nextReviewAt: next == null ? null : DateTime.tryParse(next),
    );
  }
}

class DueSummary {
  final int dueCount;
  final DateTime? nextDueAt;
  final int dueAtNextCount;

  const DueSummary({
    required this.dueCount,
    this.nextDueAt,
    this.dueAtNextCount = 0,
  });

  factory DueSummary.fromJson(Map<String, dynamic> json) {
    final next = json['nextDueAt'] as String?;
    return DueSummary(
      dueCount: (json['dueCount'] as num?)?.toInt() ?? 0,
      nextDueAt: next == null ? null : DateTime.tryParse(next),
      dueAtNextCount: (json['dueAtNextCount'] as num?)?.toInt() ?? 0,
    );
  }
}
