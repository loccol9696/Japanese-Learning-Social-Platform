import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/home/presentation/widgets/bottom_nav_dock.dart';
import 'package:frontend/features/notification/notification_hub.dart';

void main() {
  Future<void> pumpDock(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        bottomNavigationBar: BottomNavDock(selectedIndex: 0, onTabSelected: (_) {}),
      ),
    ));
  }

  final dot = find.byKey(const ValueKey('profile-notification-dot'));

  tearDown(() => NotificationHub.instance.setUnread(0));

  testWidgets('không có thông báo chưa đọc thì không hiện chấm ở tab Cá nhân', (tester) async {
    NotificationHub.instance.setUnread(0);
    await pumpDock(tester);

    expect(dot, findsNothing);
  });

  testWidgets('có thông báo chưa đọc thì hiện chấm ở tab Cá nhân', (tester) async {
    NotificationHub.instance.setUnread(3);
    await pumpDock(tester);

    expect(dot, findsOneWidget);
  });

  testWidgets('chấm tự cập nhật khi số chưa đọc thay đổi', (tester) async {
    NotificationHub.instance.setUnread(0);
    await pumpDock(tester);
    expect(dot, findsNothing);

    NotificationHub.instance.setUnread(1);
    await tester.pump();
    expect(dot, findsOneWidget);

    NotificationHub.instance.setUnread(0);
    await tester.pump();
    expect(dot, findsNothing);
  });

  test('tab Cá nhân là tab cuối cùng', () {
    expect(BottomNavDock.profileIndex, 4);
  });
}
