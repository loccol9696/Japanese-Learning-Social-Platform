import 'package:flutter/foundation.dart';

import 'dart:io' show Platform;

class ApiConstants {
  ApiConstants._();

  static const String _customHost = String.fromEnvironment('API_HOST');

  static const String _lanHost = 'https://untraitorous-huong-conversably.ngrok-free.dev/api/v1';

  /// Automatically pick host based on runtime platform
  static String get baseUrl {
    // 1. Ưu tiên giá trị truyền qua cờ --dart-define nếu có
    if (_customHost.isNotEmpty) {
      return _customHost;
    }

    // 2. Chạy trên trình duyệt Web
    if (kIsWeb) {
      return 'http://localhost:8080/api/v1';
    }

    try {
      if (Platform.isAndroid) {
        // Nếu chạy trên máy thật: BẮT BUỘC dùng IP LAN của máy tính
        // (Chỉ dùng 10.0.2.2 khi bạn debug trên Android Studio Emulator)
        return _lanHost;
      }
    } catch (_) {
      // Fallback
    }

    return 'http://localhost:8080/api/v1';
  }

  // Auth endpoints matching Spring Boot backend
  static String get loginUrl => '$baseUrl/auth/login';
  static String get googleLoginUrl => '$baseUrl/auth/google';
  static String get registerUrl => '$baseUrl/auth/register';
  static String get verifyOtpUrl => '$baseUrl/auth/verify-otp';
  static String get resendOtpUrl => '$baseUrl/auth/resend-otp';
  static String get logoutUrl => '$baseUrl/auth/logout';
  static String get refreshUrl => '$baseUrl/auth/refresh';
  static String get forgotPasswordUrl => '$baseUrl/auth/forgot-password';
  static String get resetPasswordUrl => '$baseUrl/auth/reset-password';
  static String get changePasswordUrl => '$baseUrl/auth/change-password';

  // Dictionary endpoints (tra từ trong phụ đề)
  static String get dictionaryTokenizeUrl => '$baseUrl/dictionary/tokenize';
  static String get dictionaryLookupUrl => '$baseUrl/dictionary/lookup';

  // Flashcard endpoints
  static String get flashcardSetsUrl => '$baseUrl/flashcards/sets';
  static String flashcardSetDetailUrl(int id) => '$baseUrl/flashcards/sets/$id';
  static String flashcardCardsUrl(int setId) =>
      '$baseUrl/flashcards/sets/$setId/cards';
  static String flashcardQuizUrl(int setId) =>
      '$baseUrl/flashcards/sets/$setId/quiz';
  static String flashcardMatchingUrl(int setId) =>
      '$baseUrl/flashcards/sets/$setId/matching';
  static String flashcardResetUrl(int setId) =>
      '$baseUrl/flashcards/sets/$setId/reset';
  static String flashcardStarUrl(int cardId) =>
      '$baseUrl/flashcards/cards/$cardId/star';
  static String get flashcardAnswerUrl => '$baseUrl/flashcards/study/answer';
  static String flashcardStudySessionUrl(int setId) =>
      '$baseUrl/flashcards/sets/$setId/study-session';
  static String get flashcardDueSessionUrl =>
      '$baseUrl/flashcards/study/due-session';
  static String shadowingScoreUrl(String videoId, int lineIndex) =>
      '$baseUrl/videos/$videoId/shadowing/lines/$lineIndex/score';
  static String shadowingSummaryUrl(String videoId) =>
      '$baseUrl/videos/$videoId/shadowing/summary';
  static String get flashcardReviewUrl => '$baseUrl/flashcards/study/review';
  static String get flashcardDueSummaryUrl =>
      '$baseUrl/flashcards/study/due-summary';
  static String get flashcardSaveVideoUrl => '$baseUrl/flashcards/video/save';
  static String get flashcardSaveVideoVocabUrl =>
      '$baseUrl/flashcards/video/save';
  static String speechStatusUrl(String taskId) =>
      '${baseUrl.replaceFirst('/api/v1', '/api')}/speech/status/$taskId';
  static String get analyzeGrammarUrl =>
      '${baseUrl.replaceFirst('/api/v1', '/api')}/speech/analyze-grammar';

  // Subscription endpoints
  static String get subscriptionPlansBaseUrl => '$baseUrl/subscription-plans';
  static String get subscriptionPlansUrl => subscriptionPlansBaseUrl;
  static String get subscriptionBaseUrl => '$baseUrl/subscriptions';
  static String get subscriptionCheckoutUrl =>
      '$baseUrl/subscriptions/checkout';

  /// Quota của người đang đăng nhập (server xác định qua access token).
  static String get myQuotaUrl => '$baseUrl/payments/my-quota';

  // Profile endpoints
  static String get profileUrl => '$baseUrl/profile';
  static String get topicsUrl => '$baseUrl/topics';

  // Video & Moderation endpoints
  static String get myVideosStatusUrl => '$baseUrl/videos/my-status';
  static String userVideosUrl(int userId) => '$baseUrl/users/$userId/videos';
  static String get moderationVideosUrl => '$baseUrl/videos/moderation';
  static String approveVideoUrl(int videoId) =>
      '$baseUrl/videos/$videoId/approve';
  static String rejectVideoUrl(int videoId) =>
      '$baseUrl/videos/$videoId/reject';
  static String videoUrl(int videoId) => '$baseUrl/videos/$videoId';
  static String get videoTrashUrl => '$baseUrl/videos/trash';
  static String restoreVideoUrl(int videoId) =>
      '$baseUrl/videos/$videoId/restore';
  static String permanentDeleteVideoUrl(int videoId) =>
      '$baseUrl/videos/$videoId/permanent';

  // Follow endpoints (chỉ follow lẫn nhau mới nhắn tin được)
  static String followUrl(int userId) => '$baseUrl/users/$userId/follow';
  static String get myFollowersUrl => '$baseUrl/users/me/followers';
  static String get myFollowingUrl => '$baseUrl/users/me/following';
  static String publicProfileUrl(int userId) =>
      '$baseUrl/users/$userId/public-profile';

  // Chat endpoints
  static String get chatContactsUrl => '$baseUrl/chat/contacts';
  static String get chatConversationsUrl => '$baseUrl/chat/conversations';
  static String chatConversationUrl(int id) =>
      '$baseUrl/chat/conversations/$id';
  static String chatMessagesUrl(int id) =>
      '$baseUrl/chat/conversations/$id/messages';
  static String chatReadUrl(int id) => '$baseUrl/chat/conversations/$id/read';
  static String get chatUnreadCountUrl => '$baseUrl/chat/unread-count';
  static String chatRecallUrl(int messageId) =>
      '$baseUrl/chat/messages/$messageId/recall';
  static String chatTranslationUrl(int messageId) =>
      '$baseUrl/chat/messages/$messageId/translation';
  static String chatBlockUrl(int userId) => '$baseUrl/chat/blocks/$userId';
  static String get chatDevicesUrl => '$baseUrl/chat/devices';
  static String get chatImageUploadUrl =>
      '$baseUrl/media/upload?folder=jlsp/chat';
  static String shareVideoUrl(int videoId) => '$baseUrl/videos/$videoId/share';
  static String videoDetailUrl(String videoId) => '$baseUrl/videos/$videoId';

  /// Server Socket.IO của chat: cùng host với API nhưng port riêng (9092).
  static String get socketUrl {
    final uri = Uri.parse(baseUrl);
    return Uri(scheme: uri.scheme, host: uri.host, port: 9092).toString();
  }

  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);
}
