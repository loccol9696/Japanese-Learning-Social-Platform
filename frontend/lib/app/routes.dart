import 'package:flutter/material.dart';

import '../features/auth/screens/forgot_password_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/home/presentation/screens/home_screen.dart';
import '../features/flashcard/presentation/screens/deck_library_screen.dart';
import '../features/video/presentation/screens/upload_video_screen.dart';

import '../features/video/presentation/screens/my_videos_status_screen.dart';
import '../features/video/presentation/screens/moderation_queue_screen.dart';
import '../features/profile/presentation/screens/profile_screen.dart';

class AppRoutes {
  AppRoutes._();

  static const String home = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String flashcards = '/flashcards';
  static const String upload = '/upload';
  static const String messages = '/messages';
  static const String profile = '/profile';
  static const String myVideosStatus = '/my-videos-status';
  static const String moderationQueue = '/moderation-queue';

  static Map<String, WidgetBuilder> get routes => {
    home: (context) => const HomeScreen(),
    login: (context) => const LoginScreen(),
    register: (context) => const RegisterScreen(),
    forgotPassword: (context) => const ForgotPasswordScreen(),
    flashcards: (context) => const DeckLibraryScreen(),
    upload: (context) => const UploadVideoScreen(),
    profile: (context) => const ProfileScreen(),
    myVideosStatus: (context) => const MyVideosStatusScreen(),
    moderationQueue: (context) => const ModerationQueueScreen(),
  };
}
