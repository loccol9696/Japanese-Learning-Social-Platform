import 'package:flutter/material.dart';
import '../features/home/presentation/screens/home_screen.dart';
import '../features/profile/presentation/screens/profile_update_screen.dart';

class AppRoutes {
  AppRoutes._();

  static const String home = '/';
  static const String flashcards = '/flashcards';
  static const String upload = '/upload';
  static const String messages = '/messages';
  static const String profile = '/profile';

  static Map<String, WidgetBuilder> get routes => {
        home: (context) => const HomeScreen(),
        profile: (context) => const ProfileUpdateScreen(),
      };
}
