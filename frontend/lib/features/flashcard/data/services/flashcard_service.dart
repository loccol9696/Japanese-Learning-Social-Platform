import 'package:flutter/foundation.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../models/flashcard_item_model.dart';
import '../models/flashcard_set_model.dart';
import '../models/matching_game_model.dart';
import '../models/quiz_question_model.dart';
import '../models/study_session_model.dart';

class FlashcardService {
  static FlashcardService? _instance;
  FlashcardService._();
  static FlashcardService get instance => _instance ??= FlashcardService._();

  final ApiClient _api = ApiClient.instance;

  /// Lấy danh sách bộ thẻ từ Backend API
  Future<List<FlashcardSetModel>> getSets({String? search}) async {
    String url = ApiConstants.flashcardSetsUrl;
    if (search != null && search.isNotEmpty) {
      url += '?search=${Uri.encodeComponent(search)}';
    }

    final res = await _api.get(url, withAuth: true);
    if (res is Map<String, dynamic> && res.containsKey('content')) {
      final list = res['content'] as List;
      return list
          .map((e) => FlashcardSetModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } else if (res is List) {
      return res
          .map((e) => FlashcardSetModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// Lấy chi tiết bộ thẻ theo ID từ Backend API
  Future<FlashcardSetModel> getSetById(int setId) async {
    final res = await _api.get(
      ApiConstants.flashcardSetDetailUrl(setId),
      withAuth: true,
    );
    if (res is Map<String, dynamic>) {
      return FlashcardSetModel.fromJson(res);
    }
    throw Exception('Không thể tải thông tin bộ thẻ ID: $setId');
  }

  /// Tạo bộ thẻ mới
  Future<FlashcardSetModel> createSet({
    required String title,
    String? description,
    bool isPublic = true,
  }) async {
    final res = await _api.post(
      ApiConstants.flashcardSetsUrl,
      body: {
        'title': title,
        if (description != null) 'description': description,
        'isPublic': isPublic,
      },
      withAuth: true,
    );
    return FlashcardSetModel.fromJson(res as Map<String, dynamic>);
  }

  /// Cập nhật tên và mô tả bộ thẻ
  Future<FlashcardSetModel> updateSet(
    int setId, {
    required String title,
    String? description,
    bool? isPublic,
  }) async {
    final res = await _api.put(
      ApiConstants.flashcardSetDetailUrl(setId),
      body: {
        'title': title,
        if (description != null) 'description': description,
        if (isPublic != null) 'isPublic': isPublic,
      },
      withAuth: true,
    );
    return FlashcardSetModel.fromJson(res as Map<String, dynamic>);
  }

  /// Lưu thứ tự bộ thẻ trong thư viện sau khi kéo thả ([setIds] theo thứ tự mới).
  Future<void> reorderSets(List<int> setIds) async {
    await _api.put(
      ApiConstants.flashcardSetsOrderUrl,
      body: {'ids': setIds},
      withAuth: true,
    );
  }

  /// Lưu thứ tự thẻ trong một bộ ([cardIds] theo thứ tự mới).
  Future<void> reorderCards(int setId, List<int> cardIds) async {
    await _api.put(
      ApiConstants.flashcardCardsOrderUrl(setId),
      body: {'ids': cardIds},
      withAuth: true,
    );
  }

  /// Xóa bộ thẻ
  Future<void> deleteSet(int setId) async {
    await _api.delete(
      ApiConstants.flashcardSetDetailUrl(setId),
      withAuth: true,
    );
  }

  /// Lấy danh sách thẻ trong bộ để học
  Future<List<FlashcardItemModel>> getCardsInSet(
    int setId, {
    bool starredOnly = false,
    bool shuffle = false,
  }) async {
    final url =
        '${ApiConstants.flashcardCardsUrl(setId)}?starredOnly=$starredOnly&shuffle=$shuffle';
    final res = await _api.get(url, withAuth: true);
    if (res is List) {
      return res
          .map((e) => FlashcardItemModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// Thêm thẻ mới vào bộ
  Future<FlashcardItemModel> addCard(
    int setId, {
    required String term,
    required String reading,
    String? sinoVietnamese,
    required String meaning,
    String? example,
  }) async {
    final res = await _api.post(
      ApiConstants.flashcardCardsUrl(setId),
      body: {
        'term': term,
        'reading': reading,
        if (sinoVietnamese != null) 'sinoVietnamese': sinoVietnamese,
        'meaning': meaning,
        if (example != null) 'example': example,
      },
      withAuth: true,
    );
    return FlashcardItemModel.fromJson(res as Map<String, dynamic>);
  }

  /// Cập nhật nội dung thẻ
  Future<FlashcardItemModel> updateCard(
    int cardId, {
    required String term,
    String? reading,
    String? sinoVietnamese,
    required String meaning,
    String? example,
  }) async {
    final res = await _api.put(
      '${ApiConstants.baseUrl}/flashcards/cards/$cardId',
      body: {
        'term': term,
        'reading': reading ?? '',
        if (sinoVietnamese != null) 'sinoVietnamese': sinoVietnamese,
        'meaning': meaning,
        if (example != null) 'example': example,
      },
      withAuth: true,
    );
    return FlashcardItemModel.fromJson(res as Map<String, dynamic>);
  }

  /// Xóa thẻ khỏi bộ
  Future<void> deleteCard(int cardId) async {
    await _api.delete(
      '${ApiConstants.baseUrl}/flashcards/cards/$cardId',
      withAuth: true,
    );
  }

  /// Đánh dấu hoặc bỏ gắn sao thẻ
  Future<void> updateStar(int cardId, bool isStarred) async {
    await _api.post(
      ApiConstants.flashcardStarUrl(cardId),
      body: {'isStarred': isStarred},
      withAuth: true,
    );
  }

  /// Gửi kết quả ôn tập thẻ (đúng/sai) để tính toán Spaced Repetition
  Future<void> submitAnswer(int cardId, bool isCorrect) async {
    // Các màn luyện tập gọi mà không chờ kết quả; lỗi mạng chỉ làm mất một lượt thống kê, không được làm hỏng màn học.
    try {
      await _api.post(
        ApiConstants.flashcardAnswerUrl,
        body: {'cardId': cardId, 'isCorrect': isCorrect},
        withAuth: true,
      );
    } catch (e) {
      debugPrint('Không ghi được kết quả luyện tập thẻ $cardId: $e');
    }
  }

  /// Phiên học ngắt quãng: thẻ đang học + thẻ đến hạn + thẻ mới.
  Future<StudySession> getStudySession(int setId, {int newLimit = 20}) async {
    final res = await _api.get(
      '${ApiConstants.flashcardStudySessionUrl(setId)}?newLimit=$newLimit',
      withAuth: true,
    );
    return StudySession.fromJson(res as Map<String, dynamic>);
  }

  /// Phiên ôn các thẻ đã tới hạn của mọi bộ (không gồm thẻ mới).
  Future<StudySession> getDueSession({int limit = 50}) async {
    final res = await _api.get(
      '${ApiConstants.flashcardDueSessionUrl}?limit=$limit',
      withAuth: true,
    );
    return StudySession.fromJson(res as Map<String, dynamic>);
  }

  /// Ghi nhận một lần đánh giá Xem lại / Khó / Ổn / Dễ.
  Future<ReviewResult> reviewCard(int cardId, ReviewRating rating) async {
    final res = await _api.post(
      ApiConstants.flashcardReviewUrl,
      body: {'cardId': cardId, 'rating': rating.apiName},
      withAuth: true,
    );
    return ReviewResult.fromJson(res as Map<String, dynamic>);
  }

  /// Số thẻ cần ôn và thời điểm đến hạn gần nhất (cho huy hiệu, nhắc nhở).
  Future<DueSummary> getDueSummary() async {
    final res = await _api.get(
      ApiConstants.flashcardDueSummaryUrl,
      withAuth: true,
    );
    return DueSummary.fromJson(res as Map<String, dynamic>);
  }

  /// Lấy danh sách câu hỏi trắc nghiệm từ Backend API
  Future<List<QuizQuestionModel>> getQuizQuestions(int setId) async {
    final res = await _api.get(
      ApiConstants.flashcardQuizUrl(setId),
      withAuth: true,
    );
    if (res is List) {
      return res
          .map((e) => QuizQuestionModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// Lấy dữ liệu trò chơi Ghép thẻ (Matching game) từ Backend API
  Future<MatchingGameModel> getMatchingGame(int setId) async {
    final res = await _api.get(
      ApiConstants.flashcardMatchingUrl(setId),
      withAuth: true,
    );
    if (res is Map<String, dynamic>) {
      return MatchingGameModel.fromJson(res);
    }
    throw Exception('Không thể tải bài tập ghép thẻ của bộ ID: $setId');
  }

  /// Đặt lại toàn bộ tiến trình học của bộ thẻ
  Future<void> resetProgress(int setId) async {
    await _api.post(
      ApiConstants.flashcardResetUrl(setId),
      withAuth: true,
    );
  }

  /// Lưu từ vựng từ video vào bộ "Từ vựng đã lưu từ Video"
  Future<FlashcardItemModel> saveVideoVocab({
    required String term,
    required String reading,
    String? sinoVietnamese,
    required String meaning,
    String? example,
    String? videoUrl,
  }) async {
    final res = await _api.post(
      ApiConstants.flashcardSaveVideoVocabUrl,
      body: {
        'term': term,
        'reading': reading,
        if (sinoVietnamese != null) 'sinoVietnamese': sinoVietnamese,
        'meaning': meaning,
        if (example != null) 'example': example,
        if (videoUrl != null) 'videoUrl': videoUrl,
      },
      withAuth: true,
    );
    return FlashcardItemModel.fromJson(res as Map<String, dynamic>);
  }
}
