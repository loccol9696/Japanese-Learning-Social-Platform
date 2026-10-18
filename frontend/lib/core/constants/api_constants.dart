import 'package:flutter/foundation.dart';

import 'dart:io' show Platform;

class ApiConstants {
  ApiConstants._();

  /// Automatically pick host based on runtime platform
  static String get serverUrl {
    if (kIsWeb) {
      return 'http://localhost:8080';
    }
    try {
      if (Platform.isAndroid) {
        return 'http://10.0.2.2:8080';
      }
    } catch (_) {
      // Fallback
    }
    return 'http://localhost:8080';
  }

  static String get baseUrl => '$serverUrl/api/v1';

  // User endpoints
  static String userUrl(int id) => '$baseUrl/users/$id';
  static String get profileUrl => '$baseUrl/profile'; // hồ sơ của chính người dùng (JWT)
  static String get topicsUrl => '$baseUrl/topics';
  static String get profileStatsUrl => '$baseUrl/profile/stats';
  static String get profileSavedVideosUrl => '$baseUrl/profile/saved-videos';
  static String get profileLikedVideosUrl => '$baseUrl/profile/liked-videos';
  static String get myVideosUrl => '$baseUrl/videos/my-status'; // video của mình, mọi trạng thái duyệt

  // Video & media endpoints
  static String get videosUrl => '$baseUrl/videos';
  static String mediaUploadUrl({String folder = 'jlsp'}) =>
      '$baseUrl/media/upload?folder=${Uri.encodeQueryComponent(folder)}';

  // Speech-to-Text (AI phụ đề) - nằm ngoài /api/v1 ở backend
  static String speechStatusUrl(String taskId) => '$serverUrl/api/speech/status/$taskId';

  // Auth endpoints matching Spring Boot backend
  static String get loginUrl => '$baseUrl/auth/login';
  static String get registerUrl => '$baseUrl/auth/register';
  static String get verifyOtpUrl => '$baseUrl/auth/verify-otp';
  static String get resendOtpUrl => '$baseUrl/auth/resend-otp';

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
  static String get flashcardSaveVideoUrl => '$baseUrl/flashcards/video/save';
  static String get flashcardSaveVideoVocabUrl =>
      '$baseUrl/flashcards/video/save';

  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);
}
