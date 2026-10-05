import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

class ApiConstants {
  ApiConstants._();

  /// Automatically pick host based on runtime platform
  static String get baseUrl {
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
  static String get registerUrl => '$baseUrl/auth/register';
  static String get verifyOtpUrl => '$baseUrl/auth/verify-otp';
  static String get resendOtpUrl => '$baseUrl/auth/resend-otp';

  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);
}
