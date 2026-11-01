import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/storage/token_storage.dart';
import 'package:frontend/features/auth/data/auth_session.dart';
import 'package:frontend/features/home/domain/models/video_post.dart';
import 'package:frontend/features/home/domain/repositories/home_repository.dart';
import 'package:frontend/features/home/presentation/screens/home_screen.dart';
import 'package:frontend/features/home/presentation/widgets/video_player_item.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _me = 7;

String _jwt() {
  String b64(Map<String, dynamic> map) =>
      base64Url.encode(utf8.encode(jsonEncode(map))).replaceAll('=', '');
  final exp =
      DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
      1000;
  return '${b64({'alg': 'none'})}.${b64({'exp': exp})}.sig';
}

http.Response _ok(Object? body) => http.Response(
  jsonEncode({'status': 200, 'data': body}),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

VideoPost _post(String id) => VideoPost(
  id: id,
  backgroundImageUrl: '',
  videoUrl: '',
  creatorName: 'Hana',
  creatorId: _me,
  creatorTag: '@hana',
  creatorAvatarUrl: '',
  accentInfo: '',
  jlptLevel: 'N3',
  topicTag: '',
  audioTitle: '',
  audioDiscImageUrl: '',
  rubySegments: const [],
  translation: '',
  likeCount: 0,
  commentCount: 0,
  shareCount: 0,
);

class _FakeRepository implements HomeRepository {
  final List<VideoPost> forYou;

  _FakeRepository(this.forYou);

  @override
  Future<List<VideoPost>> getForYouFeed() async => forYou;

  @override
  Future<List<VideoPost>> getFollowingFeed() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FutureOr<http.Response> Function(http.Request) server;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await TokenStorage.instance.clear();
    ApiClient.overrideForTesting(
      MockClient((request) async => server(request)),
    );
    server = (_) => _ok({
      'tokenType': 'Bearer',
      'accessToken': _jwt(),
      'refreshToken': 'rt',
      'expiresIn': 3600,
      'user': {'id': _me, 'username': 'me', 'email': 'me@example.com'},
    });
    await AuthSession.instance.login(
      email: 'me@example.com',
      password: 'secret1',
      rememberMe: true,
    );
    server = (_) => _ok(null);
  });

  tearDown(() => AuthSession.instance.logout());

  Future<void> pumpHome(WidgetTester tester, List<VideoPost> posts) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(repository: _FakeRepository(posts))),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  VideoPlayerItem activeItem(WidgetTester tester) => tester
      .widgetList<VideoPlayerItem>(find.byType(VideoPlayerItem))
      .singleWhere((item) => item.isActive);

  Future<void> deleteActive(WidgetTester tester) async {
    await tester.longPress(
      find.byWidgetPredicate((w) => w is VideoPlayerItem && w.isActive),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Xóa video'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.widgetWithText(FilledButton, 'Xóa'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    // Chờ toast tự tắt.
    await tester.pump(const Duration(seconds: 5));
  }

  testWidgets('xóa video đang xem thì video kế tiếp thế chỗ', (tester) async {
    await pumpHome(tester, [_post('1'), _post('2'), _post('3')]);
    expect(activeItem(tester).post.id, '1');

    await deleteActive(tester);

    expect(activeItem(tester).post.id, '2');
  });

  testWidgets('xóa video cuối thì lùi về video liền trước', (tester) async {
    await pumpHome(tester, [_post('1'), _post('2')]);
    await tester.drag(find.byType(VideoPlayerItem).first, const Offset(0, -700));
    // Feed có animation lặp vô hạn nên không dùng pumpAndSettle để chờ trang dừng.
    for (var frame = 0; frame < 60; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(activeItem(tester).post.id, '2');

    await deleteActive(tester);

    expect(activeItem(tester).post.id, '1');
  });

  testWidgets('xóa video duy nhất thì feed trống', (tester) async {
    await pumpHome(tester, [_post('1')]);

    await deleteActive(tester);

    expect(find.byType(VideoPlayerItem), findsNothing);
  });
}
