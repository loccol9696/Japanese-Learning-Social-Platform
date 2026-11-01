import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

http.Response _ok(Object body) => http.Response(
  jsonEncode({'status': 200, 'data': body}),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> _comment(
  int id,
  String content, {
  int userId = 100,
  int? parentId,
  bool pinned = false,
  List<Map<String, dynamic>> replies = const [],
}) => {
  'id': id,
  'videoId': 1,
  'parentId': parentId,
  'userId': userId,
  'username': 'u$id',
  'displayName': 'Người $id',
  'avatarUrl': '',
  'content': content,
  'likeCount': 0,
  'isLiked': false,
  'pinned': pinned,
  'createdAt': '2026-10-31T10:00:00',
  'replies': replies,
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

  Future<void> openSheet(WidgetTester tester, {required int ownerId}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showCommentsSheet(
                context,
                videoId: '1',
                initialCount: 1,
                videoOwnerId: ownerId,
              ),
              child: const Text('mở'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();
  }

  Future<void> longPress(WidgetTester tester, String text) async {
    await tester.longPress(find.text(text));
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
    await logIn();
  });

  testWidgets('nút Hữu ích nằm bên phải nội dung bình luận', (tester) async {
    server = (_) => _ok([_comment(1, 'nội dung bình luận')]);
    await openSheet(tester, ownerId: 999);

    final content = tester.getRect(find.text('nội dung bình luận'));
    final helpful = tester.getRect(find.byType(CommentLikeButton));

    expect(helpful.left, greaterThanOrEqualTo(content.right));
    // Thẳng hàng với mép phải của nút Gửi (cùng lề 16 của khung bình luận).
    expect(helpful.right, closeTo(tester.getRect(find.byTooltip('Gửi')).right, 1));
  });

  testWidgets('dưới bình luận chỉ còn Trả lời; Báo cáo nằm trong menu nhấn giữ', (
    tester,
  ) async {
    server = (_) => _ok([_comment(1, 'hay')]);
    await openSheet(tester, ownerId: 999);
    expect(find.text('Trả lời'), findsOneWidget);
    expect(find.text('Báo cáo'), findsNothing);

    await longPress(tester, 'hay');

    expect(find.text('Sao chép'), findsOneWidget);
    expect(find.text('Báo cáo'), findsOneWidget);
    expect(find.text('Ghim'), findsNothing);
    expect(find.text('Xóa'), findsNothing);
  });

  testWidgets('nhấn giữ bình luận của chính mình: có Xóa, không có Báo cáo', (
    tester,
  ) async {
    server = (_) => _ok([_comment(1, 'của tôi', userId: _me)]);
    await openSheet(tester, ownerId: 999);

    await longPress(tester, 'của tôi');

    expect(find.text('Xóa'), findsOneWidget);
    expect(find.text('Báo cáo'), findsNothing);
  });

  testWidgets('Sao chép đưa nội dung vào clipboard', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    server = (_) => _ok([_comment(1, 'chép tôi')]);
    await openSheet(tester, ownerId: 999);

    await longPress(tester, 'chép tôi');
    await tester.tap(find.text('Sao chép'));
    await tester.pumpAndSettle();

    expect(copied, 'chép tôi');
  });

  testWidgets('Trả lời trong menu hiện thanh "Đang trả lời"', (tester) async {
    server = (_) => _ok([_comment(1, 'hay')]);
    await openSheet(tester, ownerId: 999);

    await longPress(tester, 'hay');
    await tester.tap(find.text('Trả lời').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('Đang trả lời'), findsOneWidget);
  });

  testWidgets('người xem thường thấy nhãn Đã ghim nhưng menu không có Ghim', (
    tester,
  ) async {
    server = (_) => _ok([_comment(1, 'hay', pinned: true)]);
    await openSheet(tester, ownerId: 999);
    expect(find.text('Đã ghim'), findsOneWidget);

    await longPress(tester, 'hay');

    expect(find.text('Ghim'), findsNothing);
    expect(find.text('Bỏ ghim'), findsNothing);
  });

  testWidgets('chủ video ghim qua menu: gọi API ghim rồi tải lại danh sách', (
    tester,
  ) async {
    var pinned = false;
    server = (request) {
      if (request.method == 'POST' && request.url.path.endsWith('/pin')) {
        pinned = true;
        return _ok({'pinned': true});
      }
      return _ok([_comment(1, 'hay', pinned: pinned)]);
    };
    await openSheet(tester, ownerId: _me);
    expect(find.text('Đã ghim'), findsNothing);
    final loads = sent('GET', '/videos/1/comments').length;

    await longPress(tester, 'hay');
    await tester.tap(find.text('Ghim'));
    await tester.pumpAndSettle();

    expect(sent('POST', '/comments/1/pin'), hasLength(1));
    expect(sent('GET', '/videos/1/comments'), hasLength(loads + 1));
    expect(find.text('Đã ghim'), findsOneWidget);
  });

  testWidgets('chủ video bỏ ghim qua menu: gọi DELETE /pin', (tester) async {
    server = (request) {
      if (request.method == 'DELETE') return _ok({'pinned': false});
      return _ok([_comment(1, 'hay', pinned: true)]);
    };
    await openSheet(tester, ownerId: _me);

    await longPress(tester, 'hay');
    await tester.tap(find.text('Bỏ ghim'));
    await tester.pumpAndSettle();

    expect(sent('DELETE', '/comments/1/pin'), hasLength(1));
  });

  testWidgets('chủ video không ghim được phản hồi', (tester) async {
    server = (_) => _ok([
      _comment(
        1,
        'gốc',
        replies: [_comment(2, 'phản hồi', parentId: 1)],
      ),
    ]);
    await openSheet(tester, ownerId: _me);

    await longPress(tester, 'phản hồi');

    expect(find.text('Ghim'), findsNothing);
    expect(find.text('Sao chép'), findsOneWidget);
  });

  testWidgets('không còn nút thả tim của chủ video', (tester) async {
    server = (_) => _ok([_comment(1, 'hay')]);
    await openSheet(tester, ownerId: _me);

    await longPress(tester, 'hay');

    expect(find.text('Thả tim'), findsNothing);
    expect(find.byIcon(Icons.favorite_rounded), findsNothing);
  });
}
