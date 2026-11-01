import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/theme/app_motion.dart';
import 'package:frontend/features/chat/presentation/screens/messages_tab.dart';

void main() {
  testWidgets('màn con mở trong tab nên vẫn chừa chỗ cho thanh menu dưới', (
    tester,
  ) async {
    // Navigator riêng: push từ trong tab không phủ lên thanh menu của Home.
    final rootKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: rootKey,
        home: Scaffold(
          body: Stack(
            children: [
              const MessagesTab(bottomInset: 60),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(key: const Key('dock'), height: 60),
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('dock')), findsOneWidget);
    final tabNavigator = tester.state<NavigatorState>(
      find.descendant(
        of: find.byType(MessagesTab),
        matching: find.byType(Navigator),
      ),
    );
    tabNavigator.push(
      MaterialPageRoute(builder: (_) => const Scaffold(body: Text('chi tiết'))),
    );
    await tester.pumpAndSettle();

    expect(find.text('chi tiết'), findsOneWidget);
    expect(find.byKey(const Key('dock')), findsOneWidget);
    // Chỉ Navigator gốc (1) + Navigator của tab; trang mới nằm trong tab.
    expect(rootKey.currentState!.canPop(), isFalse);
  });

  testWidgets('báo cho Home khi vào / thoát một màn con để ẩn / hiện thanh menu', (tester) async {
    final events = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessagesTab(bottomInset: 60, onChildRouteChanged: events.add),
        ),
      ),
    );
    await tester.pump();
    // Hộp thư (tuyến gốc của tab) chưa phải màn con.
    expect(events.where((e) => e), isEmpty);

    final tabNavigator = tester.state<NavigatorState>(
      find.descendant(of: find.byType(MessagesTab), matching: find.byType(Navigator)),
    );
    tabNavigator.push(
      MaterialPageRoute(builder: (_) => const Scaffold(body: Text('khung chat'))),
    );
    await tester.pumpAndSettle();
    expect(events.last, isTrue);

    tabNavigator.pop();
    // Hộp thư hiện lại với vòng tải quay mãi nên không dùng pumpAndSettle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(events.last, isFalse);
  });

  testWidgets('ở màn con, vuốt sang phải quay về hộp thư và giữ nguyên ngăn xếp', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(pageTransitionsTheme: AppMotion.pageTransitions),
        home: const Scaffold(body: MessagesTab(bottomInset: 0)),
      ),
    );
    final tabNavigator = tester.state<NavigatorState>(
      find.descendant(of: find.byType(MessagesTab), matching: find.byType(Navigator)),
    );
    tabNavigator.push(
      MaterialPageRoute(builder: (_) => const Scaffold(body: Center(child: Text('khung chat')))),
    );
    await tester.pumpAndSettle();
    expect(find.text('khung chat'), findsOneWidget);

    await tester.fling(find.text('khung chat'), const Offset(300, 0), 1200);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('khung chat'), findsNothing);
    expect(tabNavigator.canPop(), isFalse);
  });

  testWidgets('vuốt sang trái hoặc vuốt chậm không làm quay lại', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(pageTransitionsTheme: AppMotion.pageTransitions),
        home: const Scaffold(body: MessagesTab(bottomInset: 0)),
      ),
    );
    final tabNavigator = tester.state<NavigatorState>(
      find.descendant(of: find.byType(MessagesTab), matching: find.byType(Navigator)),
    );
    tabNavigator.push(
      MaterialPageRoute(builder: (_) => const Scaffold(body: Center(child: Text('khung chat')))),
    );
    await tester.pumpAndSettle();

    await tester.fling(find.text('khung chat'), const Offset(-300, 0), 1200);
    await tester.pumpAndSettle();
    expect(find.text('khung chat'), findsOneWidget);

    await tester.drag(find.text('khung chat'), const Offset(200, 0));
    await tester.pumpAndSettle();
    expect(find.text('khung chat'), findsOneWidget);
  });

  testWidgets('hai màn con chồng nhau: thoát một màn vẫn còn "đang ở màn con", thoát hết mới về hộp thư', (tester) async {
    final events = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MessagesTab(bottomInset: 0, onChildRouteChanged: events.add)),
      ),
    );
    final tabNavigator = tester.state<NavigatorState>(
      find.descendant(of: find.byType(MessagesTab), matching: find.byType(Navigator)),
    );
    MaterialPageRoute<void> page(String text) =>
        MaterialPageRoute(builder: (_) => Scaffold(body: Text(text)));

    tabNavigator.push(page('khung chat'));
    await tester.pumpAndSettle();
    tabNavigator.push(page('trang cá nhân'));
    await tester.pumpAndSettle();
    expect(events.last, isTrue);

    tabNavigator.pop();
    await tester.pumpAndSettle();
    expect(events.last, isTrue); // vẫn đang trong khung chat

    tabNavigator.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(events.last, isFalse);
  });

  group('vuốt quay lại bám theo ngón tay', () {
    Future<NavigatorState> openChild(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
        theme: ThemeData(pageTransitionsTheme: AppMotion.pageTransitions),
        home: const Scaffold(body: MessagesTab(bottomInset: 0)),
      ),
      );
      final navigator = tester.state<NavigatorState>(
        find.descendant(of: find.byType(MessagesTab), matching: find.byType(Navigator)),
      );
      navigator.push(
        MaterialPageRoute(builder: (_) => const Scaffold(body: Center(child: Text('khung chat')))),
      );
      await tester.pumpAndSettle();
      return navigator;
    }

    testWidgets('màn con trượt theo ngón tay khi đang kéo', (tester) async {
      await openChild(tester);
      final before = tester.getTopLeft(find.text('khung chat')).dx;

      final gesture = await tester.startGesture(const Offset(400, 600));
      await gesture.moveBy(const Offset(100, 0)); // vượt ngưỡng nhận cử chỉ
      await gesture.moveBy(const Offset(200, 0));
      await tester.pump();

      expect(tester.getTopLeft(find.text('khung chat')).dx, greaterThan(before + 150));
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('thả sau khi kéo quá nửa màn thì quay về hộp thư', (tester) async {
      final navigator = await openChild(tester);

      final gesture = await tester.startGesture(const Offset(100, 600));
      await gesture.moveBy(const Offset(100, 0));
      await gesture.moveBy(const Offset(400, 0));
      await tester.pump();
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('khung chat'), findsNothing);
      expect(navigator.canPop(), isFalse);
      expect(navigator.userGestureInProgress, isFalse);
    });

    testWidgets('thả khi mới kéo ngắn thì trượt về chỗ cũ và ở lại khung chat', (tester) async {
      final navigator = await openChild(tester);

      final gesture = await tester.startGesture(const Offset(100, 600));
      await gesture.moveBy(const Offset(100, 0));
      await gesture.moveBy(const Offset(100, 0));
      await tester.pump();
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('khung chat'), findsOneWidget);
      expect(tester.getTopLeft(find.text('khung chat')).dx, closeTo(400 - 40, 60)); // vẫn ở giữa
      expect(navigator.canPop(), isTrue);
      expect(navigator.userGestureInProgress, isFalse);
    });
  });
}
