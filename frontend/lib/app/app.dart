import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import '../core/localization/locale_manager.dart';
import '../core/storage/token_storage.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/data/services/auth_service.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/home/presentation/screens/home_screen.dart';
import 'routes.dart';

class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: localeManager,
      builder: (context, _) {
        return MaterialApp(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.darkTheme,
          scrollBehavior: const AppScrollBehavior(),
          home: const _AuthGate(),
          routes: AppRoutes.routes,
          onUnknownRoute: (settings) =>
              MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      },
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  // Chỉ chạy một lần, tránh gọi logout lặp lại mỗi lần rebuild.
  late final Future<bool> _sessionFuture = _resolveSession();

  /// Chỉ vào thẳng Home khi còn token hợp lệ VÀ người dùng đã chọn
  /// "Ghi nhớ đăng nhập". Ngược lại thì đăng xuất (giải phóng phiên trên
  /// server để lần đăng nhập sau không bị báo "đang đăng nhập ở thiết bị khác").
  ///
  /// Kiểm tra "Ghi nhớ" chỉ áp dụng lần đầu khi mở app. Sau khi đăng nhập,
  /// màn Login điều hướng về route '/' (chính là _AuthGate) nên lúc đó chỉ
  /// cần token còn hạn.
  static bool _launchChecked = false;

  static Future<bool> _resolveSession() async {
    final storage = TokenStorage.instance;
    final isAppLaunch = !_launchChecked;
    _launchChecked = true;

    final hasToken = (await storage.getAccessToken())?.isNotEmpty ?? false;
    if (!hasToken) return false;

    final loggedIn = await storage.isLoggedIn();
    if (loggedIn && !isAppLaunch) return true;

    final rememberMe = await storage.getRememberMe();
    if (loggedIn && rememberMe) return true;

    await AuthService.instance.logout();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _sessionFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snapshot.data == true ? const HomeScreen() : const LoginScreen();
      },
    );
  }
}
