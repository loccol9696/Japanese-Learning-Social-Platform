import 'package:flutter/material.dart';

import '../features/auth/screens/change_password_screen.dart';
import '../features/auth/screens/forgot_password_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/flashcard/presentation/screens/deck_library_screen.dart';
import '../features/video/presentation/screens/upload_video_screen.dart';
import '../features/subscription/screens/subscription_screen.dart';

import '../features/video/presentation/screens/my_videos_status_screen.dart';
import '../features/video/presentation/screens/moderation_queue_screen.dart';
import '../features/follow/presentation/screens/blocked_users_screen.dart';
import '../features/notification/notification_screen.dart';
import '../features/profile/presentation/screens/profile_screen.dart';

class AppRoutes {
  AppRoutes._();

  static const String home = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String changePassword = '/change-password';
  static const String flashcards = '/flashcards';
  static const String upload = '/upload';
  static const String messages = '/messages';
  static const String profile = '/profile';
  static const String subscription = '/subscription';
  static const String myVideosStatus = '/my-videos-status';
  static const String moderationQueue = '/moderation-queue';
  static const String notifications = '/notifications';
  static const String blockedUsers = '/blocked-users';

  static Map<String, WidgetBuilder> get routes => {
    login: (context) => const LoginScreen(),
    register: (context) => const RegisterScreen(),
    forgotPassword: (context) => const ForgotPasswordScreen(),
    changePassword: (context) => const ChangePasswordScreen(),
    flashcards: (context) => const DeckLibraryScreen(),
    upload: (context) => const UploadVideoScreen(),
    subscription: (context) => const SubscriptionScreen(),
    profile: (context) => const ProfileScreen(),
    myVideosStatus: (context) => const MyVideosStatusScreen(),
    moderationQueue: (context) => const ModerationQueueScreen(),
    notifications: (context) => const NotificationScreen(),
    blockedUsers: (context) => const BlockedUsersScreen(),
  };
}
