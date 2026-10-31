import 'package:flutter/foundation.dart';

import 'dart:io' show Platform;

class ApiConstants {
  ApiConstants._();

  /// Địa chỉ API do người build chỉ định, ví dụ khi chạy trên điện thoại thật qua ngrok:
  /// `flutter build apk --dart-define=API_BASE_URL=https://ten-mien.ngrok-free.app/api/v1`.
  /// Để trống thì tự chọn theo nền tảng (máy ảo Android dùng 10.0.2.2).
  static const String _apiBaseUrlOverride = String.fromEnvironment('API_BASE_URL');

  /// Địa chỉ server Socket.IO của chat khi build chỉ định riêng (`--dart-define=SOCKET_URL=https://...`).
  static const String _socketUrlOverride = String.fromEnvironment('SOCKET_URL');

  /// Automatically pick host based on runtime platform
  static String get baseUrl {
    if (_apiBaseUrlOverride.isNotEmpty) {
      return _apiBaseUrlOverride.endsWith('/')
          ? _apiBaseUrlOverride.substring(0, _apiBaseUrlOverride.length - 1)
          : _apiBaseUrlOverride;
    }
    if (kIsWeb) {
      return 'http://localhost:8080/api/v1';
    }

    try {
      if (Platform.isAndroid) {
        return 'http://10.0.2.2:8080/api/v1';
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
  static String get flashcardSetsOrderUrl => '$baseUrl/flashcards/sets/order';
  static String flashcardCardsOrderUrl(int setId) =>
      '$baseUrl/flashcards/sets/$setId/cards/order';
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
  static String get streakUrl => '$baseUrl/users/me/streak';
  static String streakDaysUrl(DateTime from, DateTime to) {
    String iso(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return '$baseUrl/users/me/streak/days?from=${iso(from)}&to=${iso(to)}';
  }
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

  /// Thanh toán chuyển khoản VietQR: tạo đơn (POST) và danh sách đơn của tôi (GET).
  static String get paymentOrdersUrl => '$baseUrl/payments/orders';
  static String paymentOrderUrl(String orderCode) =>
      '$baseUrl/payments/orders/${Uri.encodeComponent(orderCode)}';

  /// Gói thành viên hiện tại của người đang đăng nhập.
  static String get mySubscriptionUrl => '$baseUrl/payments/my-subscription';

  /// Quota của người đang đăng nhập (server xác định qua access token).
  static String get myQuotaUrl => '$baseUrl/payments/my-quota';

  /// Câu hỏi chào mừng (trình độ + sở thích): đọc / lưu (GET, PUT) và bỏ qua (POST).
  static String get onboardingUrl => '$baseUrl/onboarding';
  static String get onboardingSkipUrl => '$baseUrl/onboarding/skip';

  // Profile endpoints
  static String get profileUrl => '$baseUrl/profile';
  static String get topicsUrl => '$baseUrl/topics';
  static String get reportsUrl => '$baseUrl/reports';
  static String get notificationsUrl => '$baseUrl/notifications';

  // Video & Moderation endpoints
  static String get myVideosStatusUrl => '$baseUrl/videos/my-status';
  static String userVideosUrl(int userId) => '$baseUrl/users/$userId/videos';
  static String get moderationVideosUrl => '$baseUrl/videos/moderation';
  static String approveVideoUrl(int videoId) =>
      '$baseUrl/videos/$videoId/approve';
  static String rejectVideoUrl(int videoId) =>
      '$baseUrl/videos/$videoId/reject';

  // Follow endpoints (chỉ follow lẫn nhau mới nhắn tin được)
  static String followUrl(int userId) => '$baseUrl/users/$userId/follow';
  static String userSearchUrl(String query, {int page = 0, int size = 20}) =>
      '$baseUrl/users/search?q=${Uri.encodeQueryComponent(query)}&page=$page&size=$size';
  static String blockUrl(int userId) => '$baseUrl/users/$userId/block';
  static String get blockedUsersUrl => '$baseUrl/users/me/blocked';
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
  static String shareDeckUrl(int deckId) => '$baseUrl/flashcards/sets/$deckId/share';
  static String videoDetailUrl(String videoId) => '$baseUrl/videos/$videoId';

  /// Server Socket.IO của chat: cùng host với API nhưng port riêng (9092).
  static String get socketUrl {
    if (_socketUrlOverride.isNotEmpty) return _socketUrlOverride;
    final uri = Uri.parse(baseUrl);
    return Uri(scheme: uri.scheme, host: uri.host, port: 9092).toString();
  }

  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);
}
