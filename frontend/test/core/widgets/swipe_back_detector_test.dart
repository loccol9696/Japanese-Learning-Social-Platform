import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/theme/app_motion.dart';
import 'package:frontend/core/widgets/swipe_back_detector.dart';

void main() {
  final navigatorKey = GlobalKey<NavigatorState>();

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      theme: ThemeData(pageTransitionsTheme: AppMotion.pageTransitions),
      builder: (context, child) => SwipeBackDetector(
        navigatorKey: navigatorKey,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const Scaffold(body: Center(child: Text('trang chủ'))),
    ));
  }

  Future<void> push(WidgetTester tester, Route<void> route) async {
    navigatorKey.currentState!.push(route);
    await tester.pumpAndSettle();
  }

  MaterialPageRoute<void> page(String text, {Widget? body, bool fullscreenDialog = false}) =>
      MaterialPageRoute<void>(
        fullscreenDialog: fullscreenDialog,
        builder: (_) => Scaffold(body: body ?? Center(child: Text(text))),
      );

  Future<void> swipeRight(WidgetTester tester, Finder on, {double distance = 500}) async {
    final gesture = await tester.startGesture(tester.getCenter(on));
    await gesture.moveBy(const Offset(100, 0));
    await gesture.moveBy(Offset(distance - 100, 0));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('màn được push: vuốt sang phải ở giữa màn hình thì quay lại', (tester) async {
    await pumpApp(tester);
    await push(tester, page('chi tiết'));
    expect(find.text('chi tiết'), findsOneWidget);

    await swipeRight(tester, find.text('chi tiết'));

    expect(find.text('chi tiết'), findsNothing);
    expect(find.text('trang chủ'), findsOneWidget);
    expect(navigatorKey.currentState!.userGestureInProgress, isFalse);
  });

  testWidgets('màn gốc: vuốt sang phải không làm gì', (tester) async {
    await pumpApp(tester);

    await swipeRight(tester, find.text('trang chủ'));

    expect(find.text('trang chủ'), findsOneWidget);
    expect(navigatorKey.currentState!.userGestureInProgress, isFalse);
  });

  testWidgets('màn bị PopScope chặn thì không vuốt về được', (tester) async {
    await pumpApp(tester);
    await push(
      tester,
      MaterialPageRoute<void>(
        builder: (_) => const PopScope(
          canPop: false,
          child: Scaffold(body: Center(child: Text('đang gửi'))),
        ),
      ),
    );

    await swipeRight(tester, find.text('đang gửi'));

    expect(find.text('đang gửi'), findsOneWidget);
  });

  testWidgets('màn toàn màn hình kiểu hộp thoại không vuốt về', (tester) async {
    await pumpApp(tester);
    await push(tester, page('soạn bài', fullscreenDialog: true));

    await swipeRight(tester, find.text('soạn bài'));

    expect(find.text('soạn bài'), findsOneWidget);
  });

  testWidgets('hộp thoại và bảng từ dưới lên không bị vuốt đóng nhầm', (tester) async {
    await pumpApp(tester);
    await push(tester, page('chi tiết'));
    showDialog<void>(
      context: navigatorKey.currentContext!,
      builder: (_) => const AlertDialog(content: Text('xác nhận')),
    );
    await tester.pumpAndSettle();

    await swipeRight(tester, find.text('xác nhận'));

    // Hộp thoại vẫn mở và màn bên dưới không bị kéo đi.
    expect(find.text('xác nhận'), findsOneWidget);
    expect(find.text('chi tiết'), findsOneWidget);
  });

  testWidgets('cuộn ngang bên trong màn được ưu tiên, không bị coi là quay lại', (tester) async {
    await pumpApp(tester);
    final controller = PageController(initialPage: 1);
    addTearDown(controller.dispose);
    await push(
      tester,
      page('', body: PageView(
        controller: controller,
        children: const [
          Center(child: Text('trang 1')),
          Center(child: Text('trang 2')),
        ],
      )),
    );

    await swipeRight(tester, find.text('trang 2'), distance: 600);

    // PageView nhận vuốt và lật về trang 1; màn vẫn ở lại.
    expect(find.text('trang 1'), findsOneWidget);
    expect(navigatorKey.currentState!.canPop(), isTrue);
  });

  testWidgets('kéo ngắn rồi thả thì ở lại màn hiện tại', (tester) async {
    await pumpApp(tester);
    await push(tester, page('chi tiết'));

    final gesture = await tester.startGesture(tester.getCenter(find.text('chi tiết')));
    await gesture.moveBy(const Offset(100, 0));
    await gesture.moveBy(const Offset(100, 0));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('chi tiết'), findsOneWidget);
    expect(navigatorKey.currentState!.userGestureInProgress, isFalse);
  });

  testWidgets('enabled = false thì không tạo bộ nhận cử chỉ nào', (tester) async {
    final key = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      home: SwipeBackDetector(
        navigatorKey: key,
        enabled: false,
        child: const SizedBox.expand(),
      ),
    ));

    final detector = tester.widget<GestureDetector>(
      find.descendant(of: find.byType(SwipeBackDetector), matching: find.byType(GestureDetector)).first,
    );
    expect(detector.onHorizontalDragStart, isNull);
    expect(detector.onHorizontalDragEnd, isNull);
  });
}
