import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import '../core/localization/locale_manager.dart';
import '../core/theme/app_theme.dart';
import 'routes.dart';

class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) {
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
          initialRoute: AppRoutes.login,
          routes: AppRoutes.routes,
          onUnknownRoute: (settings) => MaterialPageRoute(
            builder: (context) => AppRoutes.routes[AppRoutes.home]!(context),
          ),
        );
      },
    );
  }
}
