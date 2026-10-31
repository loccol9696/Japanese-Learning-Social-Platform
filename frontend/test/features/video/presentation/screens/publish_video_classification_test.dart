import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/storage/token_storage.dart';
import 'package:frontend/features/video/presentation/screens/upload_video_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _jwt() {
  String b64(Map<String, dynamic> map) =>
      base64Url.encode(utf8.encode(jsonEncode(map))).replaceAll('=', '');
  final exp = DateTime.now().add(const Duration(minutes: 30)).millisecondsSinceEpoch ~/ 1000;
  return '${b64({'alg': 'none'})}.${b64({'exp': exp})}.sig';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final writes = <http.Request>[];
  var videoDetail = <String, dynamic>{};

  setUpAll(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    ApiClient.overrideForTesting(MockClient((request) async {
      if (request.method != 'GET') writes.add(request);
      Object data = {};
      if (request.url.path == '/api/v1/topics') {
        data = [
          {'id': 1, 'name': 'Anime & Manga'},
          {'id': 2, 'name': 'Ẩm thực Nhật Bản'},
        ];
      } else if (request.url.path == '/api/v1/videos/7' && request.method == 'GET') {
        data = videoDetail;
      }
      return http.Response(
        jsonEncode({'status': 200, 'data': data}),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }));
  });

  setUp(() async {
    writes.clear();
    videoDetail = {};
    await TokenStorage.instance.saveTokens(accessToken: _jwt(), refreshToken: 'r');
  });

  Future<void> pumpPublish(WidgetTester tester, {int? editingVideoId}) async {
    // Đủ cao để cả màn nằm gọn phía trên thanh menu dưới, không phải cuộn tới nút Đăng.
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(MaterialApp(
      home: PublishVideoScreen(
        videoUrl: 'https://cdn/v.mp4',
        thumbnailUrl: 'https://cdn/t.jpg',
        duration: 30,
        fileName: 'Bài học',
        editingVideoId: editingVideoId,
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> publish(WidgetTester tester) async {
    await tester.tap(find.text('Đăng video bài học'));
    await tester.pumpAndSettle();
  }

  Finder hashtagField() => find.widgetWithText(TextField, 'Nhập rồi cách để thêm, ví dụ #anime');

  testWidgets('đăng video gửi nhiều chủ đề và hashtag, kể cả thẻ đang gõ dở', (tester) async {
    await pumpPublish(tester);

    await tester.tap(find.text('Anime & Manga'));
    await tester.pump();
    await tester.tap(find.text('Ẩm thực Nhật Bản'));
    await tester.pump();
    await tester.enterText(hashtagField(), '#Tokyo ramen');
    await tester.pump();

    await publish(tester);

    final body = jsonDecode(writes.single.body) as Map<String, dynamic>;
    expect(writes.single.url.path, '/api/v1/videos');
    expect(body['topicIds'], unorderedEquals([1, 2]));
    expect(body['hashtags'], ['tokyo', 'ramen']);
    expect(body.containsKey('topicId'), isFalse);
  });

  testWidgets('không chọn gì vẫn đăng được', (tester) async {
    await pumpPublish(tester);

    await publish(tester);

    final body = jsonDecode(writes.single.body) as Map<String, dynamic>;
    expect(body['topicIds'], isEmpty);
    expect(body['hashtags'], isEmpty);
  });

  testWidgets('hashtag đang gõ sai định dạng thì chưa đăng', (tester) async {
    await pumpPublish(tester);

    await tester.enterText(hashtagField(), 'c++');
    await tester.pump();
    await publish(tester);

    expect(writes, isEmpty);
    expect(find.textContaining('Hashtag chỉ gồm chữ'), findsOneWidget);
  });

  testWidgets('sửa bản nháp nạp lại chủ đề, hashtag; bỏ được cả chủ đề đã bị ẩn', (tester) async {
    videoDetail = {
      'id': 7,
      'title': 'Bản nháp',
      'jlptLevel': 'N4',
      'topics': [
        {'id': 9, 'name': 'Chủ đề đã ẩn', 'isActive': false},
      ],
      'hashtags': ['tokyo'],
    };
    await pumpPublish(tester, editingVideoId: 7);

    expect(find.text('Chủ đề đã ẩn'), findsOneWidget);
    expect(find.text('#tokyo'), findsOneWidget);

    await tester.tap(find.text('Chủ đề đã ẩn'));
    await tester.pump();
    await tester.tap(find.text('Anime & Manga'));
    await tester.pump();
    await publish(tester);

    final write = writes.single;
    expect(write.method, 'PATCH');
    final body = jsonDecode(write.body) as Map<String, dynamic>;
    expect(body['topicIds'], [1]);
    expect(body['hashtags'], ['tokyo']);
  });
}
