import 'flashcard_item_model.dart';

class FlashcardSetModel {
  final int setId;
  int get id => setId;
  final String title;
  final String? description;
  final bool isPublic;
  final bool isVideoSaved;
  final int? authorId;
  final String authorName;
  final String? authorAvatarUrl;
  final bool isAuthorPro;
  final int totalCards;
  final int learnedCards;
  final double progressPercentage;
  final List<FlashcardItemModel> previewCards;

  FlashcardSetModel({
    required this.setId,
    required this.title,
    this.description,
    this.isPublic = false,
    this.isVideoSaved = false,
    this.authorId,
    this.authorName = '',
    this.authorAvatarUrl,
    this.isAuthorPro = false,
    this.totalCards = 0,
    this.learnedCards = 0,
    this.progressPercentage = 0.0,
    this.previewCards = const [],
  });

  factory FlashcardSetModel.fromJson(Map<String, dynamic> json) {
    var rawPreview = json['previewCards'] as List? ?? [];
    List<FlashcardItemModel> preview = rawPreview
        .map((e) => FlashcardItemModel.fromJson(e as Map<String, dynamic>))
        .toList();

    return FlashcardSetModel(
      setId: json['setId'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      isPublic: json['isPublic'] as bool? ?? false,
      isVideoSaved: json['isVideoSaved'] as bool? ?? false,
      authorId: json['authorId'] as int?,
      authorName: json['authorName'] as String? ?? '',
      authorAvatarUrl: json['authorAvatarUrl'] as String?,
      isAuthorPro: json['isAuthorPro'] as bool? ?? false,
      totalCards: json['totalCards'] as int? ?? 0,
      learnedCards: json['learnedCards'] as int? ?? 0,
      progressPercentage: (json['progressPercentage'] as num?)?.toDouble() ?? 0.0,
      previewCards: preview,
    );
  }

  Map<String, dynamic> toJson() => {
        'setId': setId,
        'title': title,
        'description': description,
        'isPublic': isPublic,
        'isVideoSaved': isVideoSaved,
        'authorId': authorId,
        'authorName': authorName,
        'authorAvatarUrl': authorAvatarUrl,
        'isAuthorPro': isAuthorPro,
        'totalCards': totalCards,
        'learnedCards': learnedCards,
        'progressPercentage': progressPercentage,
        'previewCards': previewCards.map((e) => e.toJson()).toList(),
      };

  FlashcardSetModel copyWith({
    int? setId,
    String? title,
    String? description,
    bool? isPublic,
    bool? isVideoSaved,
    int? authorId,
    String? authorName,
    String? authorAvatarUrl,
    bool? isAuthorPro,
    int? totalCards,
    int learnedCards = -1,
    double? progressPercentage,
    List<FlashcardItemModel>? previewCards,
  }) {
    return FlashcardSetModel(
      setId: setId ?? this.setId,
      title: title ?? this.title,
      description: description ?? this.description,
      isPublic: isPublic ?? this.isPublic,
      isVideoSaved: isVideoSaved ?? this.isVideoSaved,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
      isAuthorPro: isAuthorPro ?? this.isAuthorPro,
      totalCards: totalCards ?? this.totalCards,
      learnedCards: learnedCards >= 0 ? learnedCards : this.learnedCards,
      progressPercentage: progressPercentage ?? this.progressPercentage,
      previewCards: previewCards ?? this.previewCards,
    );
  }
}
