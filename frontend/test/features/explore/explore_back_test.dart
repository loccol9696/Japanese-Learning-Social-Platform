import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/storage/token_storage.dart';
import 'package:frontend/core/theme/app_motion.dart';
import 'package:frontend/core/widgets/swipe_back_detector.dart';
import 'package:frontend/features/explore/presentation/explore_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final navigatorKey = GlobalKey<NavigatorState>();

  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await TokenStorage.instance.clear();
    ApiClient.overrideForTesting(MockClient((request) async {
      final path = request.url.path;
      Object data = {};
      if (path == '/api/v1/videos') {
        data = {
          'content': [
            {
              'id': 1,
              'title': 'Umayuru Thám tử lừng danh',
              'videoUrl': '',
              'thumbnailUrl': '',
              'jlptLevel': 'N2',
              'creatorDisplayName': 'Yuuka',
              'creatorUsername': 'yuukachan',
            },
          ],
          'last': true,
        };
      } else if (path == '/api/v1/topics') {
        data = [];
      }
      return http.Response(
        jsonEncode({'status': 200, 'data': data}),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }));
  });

  /// Dựng như app thật: Navigator có SwipeBackDetector bọc ngoài, Trang chủ đẩy màn Khám phá lên.
  Future<void> openExplore(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      theme: ThemeData(pageTransitionsTheme: AppMotion.pageTransitions),
      builder: (context, child) => SwipeBackDetector(
        navigatorKey: navigatorKey,
        child: child ?? const SizedBox.shrink(),
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const Scaffold(body: ExploreScreen(showBackButton: true))),
              ),
              child: const Text('trang chủ'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('trang chủ'));
    await tester.pumpAndSettle();
  }

  Future<void> swipeRight(WidgetTester tester, Offset from) async {
    final gesture = await tester.startGesture(from);
    await gesture.moveBy(const Offset(100, 0));
    await gesture.moveBy(const Offset(520, 0)); // qua hẳn nửa màn (phần đầu dùng để nhận diện cử chỉ)
    await tester.pump();
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  final searchHint = find.text('Tìm video theo tiêu đề, nội dung...');
  final feedBack = find.byTooltip('Quay lại danh sách');

  Future<void> openFirstVideo(WidgetTester tester) async {
    await tester.tap(find.text('Umayuru Thám tử lừng danh'));
    await tester.pumpAndSettle();
    expect(feedBack, findsOneWidget);
  }

  testWidgets('đang xem video từ tìm kiếm: vuốt quay lại chỉ đóng video, về danh sách kết quả', (tester) async {
    await openExplore(tester);
    expect(searchHint, findsOneWidget);
    await openFirstVideo(tester);

    await swipeRight(tester, const Offset(400, 700));

    expect(feedBack, findsNothing);
    expect(searchHint, findsOneWidget); // về lại trang tìm kiếm, chưa về Trang chủ
    expect(find.text('Umayuru Thám tử lừng danh'), findsOneWidget);
    expect(find.text('trang chủ'), findsNothing);
  });

  testWidgets('vuốt lần nữa ở danh sách kết quả mới thoát Khám phá về Trang chủ', (tester) async {
    await openExplore(tester);
    await openFirstVideo(tester);
    await swipeRight(tester, const Offset(400, 700));
    expect(searchHint, findsOneWidget);

    await swipeRight(tester, const Offset(400, 900));

    expect(searchHint, findsNothing);
    expect(find.text('trang chủ'), findsOneWidget);
  });

  testWidgets('nút Back của hệ thống khi đang xem video cũng chỉ đóng video', (tester) async {
    await openExplore(tester);
    await openFirstVideo(tester);

    await navigatorKey.currentState!.maybePop();
    await tester.pumpAndSettle();

    expect(feedBack, findsNothing);
    expect(searchHint, findsOneWidget);
    expect(find.text('trang chủ'), findsNothing);
  });

  testWidgets('nút mũi tên trên video vẫn đóng video như trước', (tester) async {
    await openExplore(tester);
    await openFirstVideo(tester);

    await tester.tap(feedBack);
    await tester.pumpAndSettle();

    expect(searchHint, findsOneWidget);
  });

  group('hiệu ứng chuyển cảnh', () {
    Future<void> tapFirstVideo(WidgetTester tester) => tester.tap(find.text('Umayuru Thám tử lừng danh'));

    testWidgets('mở video: khung video trượt vào từ bên phải rồi phủ kín', (tester) async {
      await openExplore(tester);

      await tapFirstVideo(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final early = tester.getTopLeft(feedBack).dx;
      expect(early, greaterThan(300)); // đang ở gần mép phải, chưa trượt xong

      await tester.pumpAndSettle();
      expect(tester.getTopLeft(feedBack).dx, lessThan(60)); // đã phủ kín màn hình
    });

    testWidgets('vuốt quay lại: khung video trượt theo ngón tay, danh sách kết quả hiện dần ra bên dưới', (tester) async {
      await openExplore(tester);
      await tapFirstVideo(tester);
      await tester.pumpAndSettle();
      final restingLeft = tester.getTopLeft(feedBack).dx;
      final hintAtRest = tester.getCenter(searchHint).dx;

      final gesture = await tester.startGesture(const Offset(300, 700));
      await gesture.moveBy(const Offset(100, 0)); // vượt ngưỡng nhận cử chỉ
      await gesture.moveBy(const Offset(200, 0));
      await tester.pump();

      expect(tester.getTopLeft(feedBack).dx, greaterThan(restingLeft + 150)); // video bám theo ngón tay
      expect(tester.getCenter(searchHint).dx, greaterThan(hintAtRest)); // danh sách kết quả đang trở về chỗ cũ

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('thả sớm: khung video trượt về chỗ cũ và vẫn xem video', (tester) async {
      await openExplore(tester);
      await tapFirstVideo(tester);
      await tester.pumpAndSettle();
      final restingLeft = tester.getTopLeft(feedBack).dx;

      final gesture = await tester.startGesture(const Offset(300, 700));
      await gesture.moveBy(const Offset(100, 0));
      await gesture.moveBy(const Offset(100, 0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(feedBack, findsOneWidget);
      expect(tester.getTopLeft(feedBack).dx, closeTo(restingLeft, 1));
    });

    testWidgets('thả sau khi kéo xa: khung video trượt ra có hoạt ảnh (không biến mất tức thì) rồi về danh sách', (tester) async {
      await openExplore(tester);
      await tapFirstVideo(tester);
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(const Offset(200, 700));
      await gesture.moveBy(const Offset(100, 0));
      await gesture.moveBy(const Offset(420, 0));
      await tester.pump();
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));

      // Vẫn đang trượt ra, khung video chưa bị gỡ.
      expect(feedBack, findsOneWidget);

      await tester.pumpAndSettle();
      expect(feedBack, findsNothing);
      expect(searchHint, findsOneWidget);
    });

    testWidgets('nút mũi tên cũng trượt ra có hoạt ảnh', (tester) async {
      await openExplore(tester);
      await tapFirstVideo(tester);
      await tester.pumpAndSettle();

      await tester.tap(feedBack);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(feedBack, findsOneWidget); // đang trượt, chưa biến mất

      await tester.pumpAndSettle();
      expect(feedBack, findsNothing);
    });

    testWidgets('danh sách kết quả giữ nguyên vị trí cuộn sau khi xem video rồi quay lại', (tester) async {
      await openExplore(tester);
      final titleBefore = tester.getTopLeft(find.text('Umayuru Thám tử lừng danh'));

      await tapFirstVideo(tester);
      await tester.pumpAndSettle();
      await tester.tap(feedBack);
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(find.text('Umayuru Thám tử lừng danh')), titleBefore);
    });
  });
}
