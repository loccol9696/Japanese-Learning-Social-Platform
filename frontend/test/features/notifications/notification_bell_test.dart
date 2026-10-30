import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/theme/adaptive_video_theme.dart';
import 'package:frontend/features/home/presentation/widgets/home_header.dart';
import 'package:frontend/features/notifications/presentation/widgets/notification_bell.dart';

void main() {
  const theme = AdaptiveVideoTheme(isLight: false);

  Future<ValueNotifier<int>> pumpBell(
    WidgetTester tester, {
    int unread = 0,
    VoidCallback? onTap,
  }) async {
    final notifier = ValueNotifier<int>(unread);
    addTearDown(notifier.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NotificationBell(
            theme: theme,
            unread: notifier,
            onTap: onTap ?? () {},
          ),
        ),
      ),
    );
    return notifier;
  }

  testWidgets('không có thông báo chưa đọc thì không hiện huy hiệu', (
    tester,
  ) async {
    await pumpBell(tester);

    expect(find.byKey(const ValueKey('notification-badge')), findsNothing);
  });

  testWidgets('hiện số chưa đọc và cập nhật theo thời gian thực', (tester) async {
    final unread = await pumpBell(tester, unread: 3);
    expect(find.text('3'), findsOneWidget);

    unread.value = 150;
    await tester.pump();
    expect(find.text('99+'), findsOneWidget);

    unread.value = 0;
    await tester.pump();
    expect(find.byKey(const ValueKey('notification-badge')), findsNothing);
  });

  testWidgets('bấm vào chuông gọi onTap', (tester) async {
    var taps = 0;
    await pumpBell(tester, onTap: () => taps++);

    await tester.tap(find.byIcon(Icons.notifications_none_rounded));

    expect(taps, 1);
  });

  testWidgets('header Home chỉ hiện chuông khi có onNotificationsTap', (
    tester,
  ) async {
    Widget header({VoidCallback? onNotificationsTap}) => MaterialApp(
      home: Scaffold(
        body: HomeHeader(
          currentTab: FeedTab.forYou,
          onTabChanged: (_) {},
          onNotificationsTap: onNotificationsTap,
        ),
      ),
    );

    await tester.pumpWidget(header());
    expect(find.byIcon(Icons.notifications_none_rounded), findsNothing);

    await tester.pumpWidget(header(onNotificationsTap: () {}));
    expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
  });
}
