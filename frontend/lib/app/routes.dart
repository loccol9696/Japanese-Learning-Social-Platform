import 'package:flutter/material.dart';
import '../features/auth/screens/forgot_password_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/home/presentation/screens/home_screen.dart';

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

  static Map<String, WidgetBuilder> get routes => {
        home: (context) => const HomeScreen(),
        login: (context) => const LoginScreen(),
        register: (context) => const RegisterScreen(),
        forgotPassword: (context) => const ForgotPasswordScreen(),
      };
}
