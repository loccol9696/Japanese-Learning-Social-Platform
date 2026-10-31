import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/storage/token_storage.dart';
import 'package:frontend/features/auth/data/auth_session.dart';
import 'package:frontend/features/home/presentation/widgets/comment_like_button.dart';
import 'package:frontend/features/home/presentation/widgets/comments_sheet.dart';
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

http.Response _json(int status, Object body) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

http.Response _ok(Object body) => _json(200, {'status': 200, 'data': body});

Map<String, dynamic> _comment(
  int id,
  String content, {
  int userId = 100,
  int likeCount = 0,
  bool isLiked = false,
}) => {
  'id': id,
  'videoId': 1,
  'parentId': null,
  'userId': userId,
  'username': 'u$id',
  'displayName': 'Người $id',
  'avatarUrl': '',
  'content': content,
  'likeCount': likeCount,
  'isLiked': isLiked,
  'createdAt': '2026-10-31T10:00:00',
  'replies': const [],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<http.Request> requests;
  late FutureOr<http.Response> Function(http.Request) server;

  List<http.Request> sent(String method, String pathEnd) => requests
      .where((r) => r.method == method && r.url.path.endsWith(pathEnd))
      .toList();

  Future<void> logIn() async {
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
    requests.clear();
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  showCommentsSheet(context, videoId: '1', initialCount: 2),
              child: const Text('mở'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();
  }

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await TokenStorage.instance.clear();
    requests = [];
    ApiClient.overrideForTesting(
      MockClient((request) async {
        requests.add(request);
        return server(request);
      }),
    );
    await AuthSession.instance.logout();
    requests.clear();
  });

  group('đã đăng nhập', () {
    setUp(logIn);

    testWidgets('mặc định hữu ích nhất, có gửi token để biết isLiked', (
      tester,
    ) async {
      server = (_) => _ok([_comment(1, 'hay', likeCount: 3, isLiked: true)]);

      await openSheet(tester);

      final fetch = sent('GET', '/videos/1/comments').single;
      expect(fetch.url.queryParameters['sort'], 'HELPFUL');
      expect(fetch.headers['Authorization'], startsWith('Bearer '));
      expect(find.text('3'), findsOneWidget);
      expect(find.byIcon(Icons.thumb_up_rounded), findsOneWidget);
    });

    testWidgets('đổi sort gọi lại API và đổi thứ tự', (tester) async {
      server = (request) => _ok(
        request.url.queryParameters['sort'] == 'NEWEST'
            ? [_comment(2, 'mới'), _comment(1, 'cũ', likeCount: 5)]
            : [_comment(1, 'cũ', likeCount: 5), _comment(2, 'mới')],
      );
      await openSheet(tester);
      expect(
        tester.getTopLeft(find.text('cũ')).dy,
        lessThan(tester.getTopLeft(find.text('mới')).dy),
      );

      await tester.tap(find.text('Mới nhất'));
      await tester.pumpAndSettle();

      expect(
        sent('GET', '/comments').last.url.queryParameters['sort'],
        'NEWEST',
      );
      expect(
        tester.getTopLeft(find.text('mới')).dy,
        lessThan(tester.getTopLeft(find.text('cũ')).dy),
      );
    });

    testWidgets('response đến muộn của sort cũ không ghi đè sort mới', (
      tester,
    ) async {
      final slowHelpful = Completer<http.Response>();
      var calls = 0;
      server = (request) {
        calls++;
        if (calls == 1) return _ok([_comment(1, 'ban đầu')]);
        return request.url.queryParameters['sort'] == 'HELPFUL'
            ? slowHelpful.future
            : _ok([_comment(3, 'danh sách mới nhất')]);
      };
      await openSheet(tester);

      await tester.tap(find.text('Mới nhất'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hữu ích nhất'));
      await tester.pump();
      await tester.tap(find.text('Mới nhất'));
      await tester.pumpAndSettle();

      slowHelpful.complete(_ok([_comment(2, 'kết quả cũ')]));
      await tester.pumpAndSettle();

      expect(find.text('danh sách mới nhất'), findsOneWidget);
      expect(find.text('kết quả cũ'), findsNothing);
    });

    testWidgets('nhấn hữu ích: lấy số từ backend, không đổi vị trí', (
      tester,
    ) async {
      server = (request) {
        if (request.method == 'POST') {
          return _ok({'isLiked': true, 'likeCount': 9});
        }
        return _ok([_comment(1, 'trên', likeCount: 2), _comment(2, 'dưới')]);
      };
      await openSheet(tester);
      final topBefore = tester.getTopLeft(find.text('trên')).dy;

      await tester.tap(find.byType(CommentLikeButton).last);
      await tester.pumpAndSettle();

      expect(sent('POST', '/comments/2/likes'), hasLength(1));
      expect(find.text('9'), findsOneWidget);
      expect(tester.getTopLeft(find.text('trên')).dy, topBefore);
      expect(sent('GET', '/comments'), hasLength(1));
    });

    testWidgets('bỏ đánh giá gọi DELETE', (tester) async {
      server = (request) {
        if (request.method == 'DELETE') {
          return _ok({'isLiked': false, 'likeCount': 0});
        }
        return _ok([_comment(1, 'hay', likeCount: 1, isLiked: true)]);
      };
      await openSheet(tester);

      await tester.tap(find.byType(CommentLikeButton));
      await tester.pumpAndSettle();

      expect(sent('DELETE', '/comments/1/likes'), hasLength(1));
      expect(find.byIcon(Icons.thumb_up_rounded), findsNothing);
      expect(find.text('Hữu ích'), findsOneWidget);
    });

    testWidgets('lỗi thì trả lại trạng thái cũ', (tester) async {
      server = (request) {
        if (request.method == 'POST') {
          return _json(500, {'status': 500, 'message': 'lỗi'});
        }
        return _ok([_comment(1, 'hay', likeCount: 2)]);
      };
      await openSheet(tester);

      await tester.tap(find.byType(CommentLikeButton));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      expect(find.text('2'), findsOneWidget);
      expect(find.byIcon(Icons.thumb_up_outlined), findsOneWidget);
    });

    testWidgets('nhấn liên tiếp chỉ gửi một request', (tester) async {
      final pending = Completer<http.Response>();
      server = (request) => request.method == 'POST'
          ? pending.future
          : _ok([_comment(1, 'hay')]);
      await openSheet(tester);

      await tester.tap(find.byType(CommentLikeButton));
      await tester.pump();
      await tester.tap(find.byType(CommentLikeButton));
      await tester.pump();

      expect(sent('POST', '/likes'), hasLength(1));
      pending.complete(_ok({'isLiked': true, 'likeCount': 1}));
      await tester.pumpAndSettle();
    });

    testWidgets('không tự đánh giá bình luận của mình', (tester) async {
      server = (_) => _ok([_comment(1, 'của tôi', userId: _me, likeCount: 4)]);
      await openSheet(tester);

      expect(find.text('4'), findsOneWidget);
      await tester.tap(find.byType(CommentLikeButton));
      await tester.pumpAndSettle();

      expect(sent('POST', '/likes'), isEmpty);
    });
  });

  testWidgets('khách nhấn hữu ích được yêu cầu đăng nhập, không gửi vote', (
    tester,
  ) async {
    server = (_) => _ok([_comment(1, 'hay')]);
    await openSheet(tester);
    expect(
      sent('GET', '/comments').single.headers.containsKey('Authorization'),
      isFalse,
    );

    await tester.tap(find.byType(CommentLikeButton));
    await tester.pumpAndSettle();

    expect(find.text('Vui lòng đăng nhập để đánh giá bình luận.'), findsOneWidget);
    expect(sent('POST', '/likes'), isEmpty);
  });
}
