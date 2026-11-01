import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/storage/token_storage.dart';
import 'package:frontend/features/chat/presentation/screens/shared_video_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _ok(Object body) => http.Response(
  jsonEncode({'status': 200, 'data': body}),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<http.Request> requests;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await TokenStorage.instance.clear();
    requests = [];
    ApiClient.overrideForTesting(
      MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/comments')) return _ok([]);
        return _ok({
          'id': 9,
          'title': 'Bài 1',
          'creatorId': 5,
          'creatorUsername': 'owner',
          'jlptLevel': 'N5',
          'videoUrl': '',
          'thumbnailUrl': '',
          'commentCount': 0,
        });
      }),
    );
  });

  Future<void> open(WidgetTester tester, {required bool openComments}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SharedVideoScreen(videoId: 9, openComments: openComments),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('openComments: video tải xong thì tự mở khung bình luận', (
    tester,
  ) async {
    await open(tester, openComments: true);

    expect(find.text('0 bình luận'), findsOneWidget);
    expect(requests.where((r) => r.url.path.endsWith('/videos/9/comments')), hasLength(1));
  });

  testWidgets('mặc định không tự mở khung bình luận', (tester) async {
    await open(tester, openComments: false);

    expect(find.text('0 bình luận'), findsNothing);
    expect(requests.where((r) => r.url.path.endsWith('/comments')), isEmpty);
  });
}
