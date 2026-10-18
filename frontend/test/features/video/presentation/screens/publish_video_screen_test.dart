import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/features/video/presentation/screens/publish_video_screen.dart';
import 'package:frontend/features/video/presentation/screens/upload_video_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(Object body, [int status = 200]) => http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  late List<http.Request> requests;

  void useApi(http.Response Function(http.Request req) handler) {
    requests = [];
    ApiClient.instanceForTest = ApiClient.withClient(
      MockClient((req) async {
        requests.add(req);
        return handler(req);
      }),
      tokenProvider: () async => 'tok',
    );
  }

  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => ApiClient.instanceForTest = null);

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Mở màn theo đúng luồng thật: root → (màn tải lên) → màn đăng.
  Future<void> pumpPublish(WidgetTester tester, {String? aiTaskId}) async {
    tester.view.physicalSize = const Size(412, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigator,
      home: const Text('root'),
    ));
    navigator.currentState!.push(MaterialPageRoute(builder: (_) => const Text('upload')));
    navigator.currentState!.push(MaterialPageRoute(
      builder: (_) => PublishVideoScreen(
        videoUrl: 'https://cdn/v.mp4',
        thumbnailUrl: 'https://cdn/v.jpg',
        duration: 0,
        fileName: 'bai_hoc_1.mp4',
        aiTaskId: aiTaskId,
      ),
    ));
    await settle(tester);
  }

  group('PublishVideoScreen', () {
    testWidgets('nạp phụ đề AI khi task COMPLETED', (tester) async {
      useApi((_) => _json({
            'data': {
              'status': 'COMPLETED',
              'segments': [
                {'startTime': 0, 'endTime': 3, 'text': 'こんにちは', 'translatedText': 'Xin chào'},
              ],
            },
          }));
      await pumpPublish(tester, aiTaskId: 't1');
      expect(requests, isEmpty); // không tự gọi AI khi mở màn

      await tester.tap(find.text('Tạo bằng AI'));
      await settle(tester);
      expect(requests.single.url.path, '/api/speech/status/t1');
      expect(find.text('こんにちは'), findsOneWidget);
      expect(find.text('00:00 - 00:03'), findsOneWidget);
    });

    testWidgets('AI thất bại → hiện errorMessage từ backend', (tester) async {
      useApi((_) => _json({
            'data': {'status': 'FAILED', 'errorMessage': 'Không nhận dạng được giọng nói'},
          }));
      await pumpPublish(tester, aiTaskId: 't2');
      await tester.tap(find.text('Tạo bằng AI'));
      await settle(tester);

      expect(find.text('Không nhận dạng được giọng nói'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('rời màn hình thì ngừng hỏi trạng thái AI', (tester) async {
      useApi((_) => _json({'data': {'status': 'PROCESSING'}}));
      await pumpPublish(tester, aiTaskId: 't3');
      await tester.tap(find.text('Tạo bằng AI'));
      await settle(tester);
      expect(requests, hasLength(1));

      await tester.tap(find.byIcon(Icons.arrow_back));
      await settle(tester);
      await tester.pump(const Duration(seconds: 30));

      expect(requests.length, lessThanOrEqualTo(2));
    });

    testWidgets('"Tự nhập": thêm đoạn phụ đề và gửi kèm khi đăng', (tester) async {
      useApi((req) => _json({'data': {'videoId': 1}}));
      await pumpPublish(tester);

      await tester.tap(find.text('Tự nhập'));
      await settle(tester);
      expect(find.text('Thêm đoạn phụ đề'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'Tiếng Nhật'), 'こんにちは');
      await tester.enterText(find.widgetWithText(TextField, 'Bản dịch'), 'Xin chào');
      await tester.tap(find.text('Đăng video bài học'));
      await settle(tester);

      final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
      expect(jsonDecode(body['subtitles'] as String), [
        {'start': '00:00', 'end': '00:01', 'text': 'こんにちは', 'translation': 'Xin chào'},
      ]);
      expect(requests.single.headers.containsKey('X-User-Id'), isFalse);
    });

    testWidgets('đăng gửi đúng body và đóng cả màn tải lên', (tester) async {
      useApi((req) => _json({'data': {'videoId': 1}}));
      await pumpPublish(tester);

      expect(find.text('bai_hoc_1'), findsOneWidget); // tiêu đề mặc định = tên tệp
      expect(find.text('9/100'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, '  Bài 1: Chào hỏi ');
      await tester.pump();
      expect(find.text('18/100'), findsOneWidget);
      await tester.tap(find.text('N3'));
      await tester.tap(find.text('Công khai'));
      await tester.pump();
      await tester.tap(find.text('Đăng video bài học'));
      await settle(tester);

      final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
      expect(requests.single.method, 'POST');
      expect(body['title'], 'Bài 1: Chào hỏi');
      expect(body['jlptLevel'], 'N3');
      expect(body['status'], 'PRIVATE');
      expect(body['duration'], 1);
      expect(body['description'], isNull);
      expect(body['subtitles'], isNull);
      expect(find.text('root'), findsOneWidget);
    });

    testWidgets('tiêu đề trống → báo lỗi, không gọi API', (tester) async {
      useApi((_) => _json({'data': null}));
      await pumpPublish(tester);

      await tester.enterText(find.byType(TextField).first, '   ');
      await tester.tap(find.text('Đăng video bài học'));
      await settle(tester);

      expect(find.text('Vui lòng nhập tiêu đề và ảnh bìa.'), findsOneWidget);
      expect(requests, isEmpty);
    });
  });

  group('UploadVideoScreen', () {
    Future<void> pumpUpload(WidgetTester tester, {double width = 412}) async {
      tester.view.physicalSize = Size(width, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: UploadVideoScreen()));
      await settle(tester);
    }

    testWidgets('link YouTube không hợp lệ → báo lỗi', (tester) async {
      await pumpUpload(tester);

      await tester.tap(find.text('Liên kết YouTube'));
      await settle(tester);
      await tester.enterText(find.byType(TextField), 'https://vimeo.com/123');
      await tester.tap(find.text('Nhập video từ YouTube'));
      await settle(tester);

      expect(find.text('Vui lòng nhập một đường link YouTube hợp lệ.'), findsOneWidget);
    });

    testWidgets('chưa chọn tệp → nhắc chọn video', (tester) async {
      await pumpUpload(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Tải video lên'));
      await settle(tester);

      expect(find.text('Vui lòng chọn tệp video trước khi tải lên.'), findsOneWidget);
    });

    testWidgets('màn hẹp: nhãn tab không tràn', (tester) async {
      await pumpUpload(tester, width: 320);
      expect(tester.takeException(), isNull);
    });
  });
}
