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

  group('SwipeBackOverride', () {
    /// Màn có trạng thái con: [inChild] true thì vuốt quay lại / nút Back chỉ thu về trạng thái cha.
    Widget childAwareScreen(ValueNotifier<bool> inChild, List<String> log) => ValueListenableBuilder<bool>(
      valueListenable: inChild,
      builder: (context, active, _) => SwipeBackOverride(
        active: active,
        onBack: () {
          log.add('thu về');
          inChild.value = false;
        },
        child: PopScope(
          canPop: !active,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && active) {
              log.add('thu về (nút Back)');
              inChild.value = false;
            }
          },
          child: Scaffold(body: Center(child: Text(active ? 'chế độ con' : 'danh sách'))),
        ),
      ),
    );

    testWidgets('đang ở trạng thái con: vuốt chỉ thu về trạng thái cha, không đóng cả màn', (tester) async {
      await pumpApp(tester);
      final inChild = ValueNotifier<bool>(true);
      final log = <String>[];
      await push(tester, MaterialPageRoute<void>(builder: (_) => childAwareScreen(inChild, log)));
      expect(find.text('chế độ con'), findsOneWidget);

      await swipeRight(tester, find.text('chế độ con'));

      expect(log, ['thu về']);
      expect(find.text('danh sách'), findsOneWidget); // vẫn ở màn này
      expect(navigatorKey.currentState!.canPop(), isTrue);

      // Hết trạng thái con: lần vuốt sau đóng cả màn như bình thường.
      await swipeRight(tester, find.text('danh sách'));
      expect(find.text('danh sách'), findsNothing);
      expect(find.text('trang chủ'), findsOneWidget);
    });

    testWidgets('nút Back của hệ thống cũng chỉ thu về trạng thái cha', (tester) async {
      await pumpApp(tester);
      final inChild = ValueNotifier<bool>(true);
      final log = <String>[];
      await push(tester, MaterialPageRoute<void>(builder: (_) => childAwareScreen(inChild, log)));

      await navigatorKey.currentState!.maybePop();
      await tester.pumpAndSettle();

      expect(log, ['thu về (nút Back)']);
      expect(find.text('danh sách'), findsOneWidget);
    });

    testWidgets('kéo ngắn và chậm thì chưa tính là quay lại', (tester) async {
      await pumpApp(tester);
      final inChild = ValueNotifier<bool>(true);
      final log = <String>[];
      await push(tester, MaterialPageRoute<void>(builder: (_) => childAwareScreen(inChild, log)));

      final gesture = await tester.startGesture(tester.getCenter(find.text('chế độ con')));
      await gesture.moveBy(const Offset(30, 0));
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump(const Duration(seconds: 1)); // dừng lại: tốc độ về 0
      await gesture.up();
      await tester.pumpAndSettle();

      expect(log, isEmpty);
      expect(find.text('chế độ con'), findsOneWidget);
    });

    testWidgets('màn khác đè lên trên: vuốt đóng màn trên cùng, hàm của màn bên dưới không bị gọi', (tester) async {
      await pumpApp(tester);
      final inChild = ValueNotifier<bool>(true);
      final log = <String>[];
      await push(tester, MaterialPageRoute<void>(builder: (_) => childAwareScreen(inChild, log)));
      await push(
        tester,
        MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Center(child: Text('trang cá nhân')))),
      );

      await swipeRight(tester, find.text('trang cá nhân'));

      expect(log, isEmpty);
      expect(find.text('trang cá nhân'), findsNothing);
      expect(find.text('chế độ con'), findsOneWidget);
    });

    testWidgets('onDragDelta nhận phần chiều rộng đã kéo; onDragEnd(true) khi kéo đủ xa, thay cho onBack', (tester) async {
      await pumpApp(tester);
      final deltas = <double>[];
      final ends = <bool>[];
      var backCalls = 0;
      await push(
        tester,
        MaterialPageRoute<void>(
          builder: (_) => SwipeBackOverride(
            active: true,
            onBack: () => backCalls++,
            onDragDelta: deltas.add,
            onDragEnd: ends.add,
            child: const Scaffold(body: Center(child: Text('có kéo theo tay'))),
          ),
        ),
      );

      await swipeRight(tester, find.text('có kéo theo tay'));

      expect(deltas, isNotEmpty);
      expect(deltas.every((d) => d > 0), isTrue);
      // Tổng phần đã kéo xấp xỉ quãng ngón tay di chuyển / chiều rộng màn (800).
      expect(deltas.fold<double>(0, (a, b) => a + b), closeTo(0.5, 0.15));
      expect(ends, [true]);
      expect(backCalls, 0);
    });

    testWidgets('kéo ngắn rồi thả: onDragEnd(false) để màn tự trả nội dung về chỗ cũ', (tester) async {
      await pumpApp(tester);
      final ends = <bool>[];
      await push(
        tester,
        MaterialPageRoute<void>(
          builder: (_) => SwipeBackOverride(
            active: true,
            onBack: () {},
            onDragDelta: (_) {},
            onDragEnd: ends.add,
            child: const Scaffold(body: Center(child: Text('kéo ngắn'))),
          ),
        ),
      );

      final gesture = await tester.startGesture(tester.getCenter(find.text('kéo ngắn')));
      await gesture.moveBy(const Offset(60, 0));
      await gesture.moveBy(const Offset(60, 0));
      await tester.pump(const Duration(milliseconds: 800)); // dừng lại trước khi thả: tốc độ về 0
      await gesture.up();
      await tester.pumpAndSettle();

      expect(ends, [false]);
    });
  });
}
