import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import '../core/localization/locale_manager.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/data/auth_session.dart';
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

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();
  StreamSubscription<void>? _expiredSubscription;

  @override
  void initState() {
    super.initState();
    // Phiên hết hạn ở bất kỳ màn nào: về màn Đăng nhập và báo cho người dùng.
    _expiredSubscription = AuthSession.instance.sessionExpired.listen((_) {
      _navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
      _messengerKey.currentState
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    });
  }

  @override
  void dispose() {
    _expiredSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: localeManager,
      builder: (context, _) {
        return MaterialApp(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          navigatorKey: _navigatorKey,
          scaffoldMessengerKey: _messengerKey,
          theme: AppTheme.darkTheme,
          scrollBehavior: const AppScrollBehavior(),
          home: const AuthGate(),
          routes: AppRoutes.routes,
          onUnknownRoute: (settings) =>
              MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      },
    );
  }
}

/// Màn khởi đầu: khôi phục phiên đã lưu rồi vào Home hoặc Đăng nhập.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  /// "Ghi nhớ đăng nhập" chỉ xét lúc mở app. Sau khi đăng nhập, màn Login
  /// điều hướng về route '/' (chính là AuthGate) nên lúc đó chỉ cần phiên hợp lệ.
  static bool _launchChecked = false;

  late final Future<bool> _sessionFuture = _restore();

  static Future<bool> _restore() {
    final isAppLaunch = !_launchChecked;
    _launchChecked = true;
    return AuthSession.instance.restore(isAppLaunch: isAppLaunch);
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
