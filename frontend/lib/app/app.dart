import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import '../core/localization/locale_manager.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/theme_manager.dart';
import '../core/widgets/app_toast.dart';
import '../core/widgets/swipe_back_detector.dart';
import '../features/auth/data/auth_session.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/onboarding/data/onboarding_service.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/chat/data/services/chat_hub.dart';
import '../features/notification/notification_hub.dart';
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
  StreamSubscription<void>? _expiredSubscription;

  @override
  void initState() {
    super.initState();
    // Chat: bật/tắt socket theo đăng nhập và theo dõi số tin chưa đọc.
    ChatHub.instance.init();
    // Thông báo: giữ số chưa đọc và nhận thông báo mới qua cùng kết nối socket.
    NotificationHub.instance.init();
    // Theme: khôi phục lựa chọn sáng/tối đã lưu; đổi theme thì dựng lại toàn bộ
    // cây widget để cả các widget `const` cũng nhận màu mới.
    themeManager.init();
    themeManager.addListener(_rebuildEverything);
    // Phiên hết hạn ở bất kỳ màn nào: về màn Đăng nhập và báo cho người dùng.
    _expiredSubscription = AuthSession.instance.sessionExpired.listen((_) {
      AppToast.navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
      AppToast.showInfo('Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại');
    });
  }

  @override
  void dispose() {
    themeManager.removeListener(_rebuildEverything);
    _expiredSubscription?.cancel();
    super.dispose();
  }

  /// Màu được đọc qua getter toàn cục nên widget `const` sẽ không tự dựng lại;
  /// đánh dấu mọi element cần build để giữ nguyên route hiện tại mà vẫn đổi màu.
  void _rebuildEverything() {
    void mark(Element element) {
      element.markNeedsBuild();
      element.visitChildren(mark);
    }

    WidgetsBinding.instance.rootElement?.visitChildren(mark);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([localeManager, themeManager]),
      builder: (context, _) {
        return MaterialApp(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          navigatorKey: AppToast.navigatorKey,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeManager.mode,
          scrollBehavior: const AppScrollBehavior(),
          // Mọi màn có nút quay lại đều vuốt ngang sang phải để về được, giống tab Tin nhắn.
          builder: (context, child) => SwipeBackDetector(
            navigatorKey: AppToast.navigatorKey,
            child: child ?? const SizedBox.shrink(),
          ),
          home: const AuthGate(),
          routes: AppRoutes.routes,
          onUnknownRoute: (settings) =>
              MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      },
    );
  }
}

/// Màn khởi đầu: khôi phục phiên đã lưu rồi vào Home, kể cả khi là guest.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  /// "Ghi nhớ đăng nhập" chỉ xét lúc mở app. Sau khi đăng nhập, màn Login
  /// điều hướng về route '/' (chính là AuthGate) nên lúc đó chỉ cần phiên hợp lệ.
  static bool _launchChecked = false;

  /// Đăng nhập xong (email, Google, đăng ký) đều quay về route '/' này, nên kiểm câu hỏi chào mừng ở đây là đủ.
  late final Future<bool> _ready = _prepare();

  /// Đã trả lời hoặc bỏ qua câu hỏi chào mừng trong lần mở này.
  bool _onboardingDone = false;

  static Future<bool> _restore() {
    final isAppLaunch = !_launchChecked;
    _launchChecked = true;
    return AuthSession.instance.restore(isAppLaunch: isAppLaunch);
  }

  /// Khôi phục phiên, rồi (nếu đã đăng nhập) hỏi server có cần câu hỏi chào mừng không.
  static Future<bool> _prepare() async {
    final authenticated = await _restore();
    if (!authenticated) return false;
    return OnboardingService.instance.needsOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _ready,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if ((snapshot.data ?? false) && !_onboardingDone) {
          return OnboardingScreen(
            onFinished: () => setState(() => _onboardingDone = true),
          );
        }
        return const HomeScreen();
      },
    );
  }
}
