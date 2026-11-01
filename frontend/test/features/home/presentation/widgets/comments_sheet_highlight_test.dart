import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/storage/token_storage.dart';
import 'package:frontend/core/theme/app_palette.dart';
import 'package:frontend/features/auth/data/auth_session.dart';
import 'package:frontend/features/home/presentation/widgets/comments_sheet.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _ok(Object body) => http.Response(
  jsonEncode({'status': 200, 'data': body}),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> _comment(
  int id,
  String content, {
  int? parentId,
  List<Map<String, dynamic>> replies = const [],
}) => {
  'id': id,
  'videoId': 1,
  'parentId': parentId,
  'userId': 100,
  'username': 'u$id',
  'displayName': 'Người $id',
  'avatarUrl': '',
  'content': content,
  'likeCount': 0,
  'isLiked': false,
  'createdAt': '2026-10-31T10:00:00',
  'replies': replies,
};

/// 40 bình luận gốc, bình luận 38 có một phản hồi (id 380): đủ dài để phần cuối nằm ngoài màn hình.
List<Map<String, dynamic>> _thread() => [
  for (var i = 1; i <= 40; i++)
    _comment(
      i,
      'bình luận số $i',
      replies: i == 38 ? [_comment(380, 'phản hồi cuối', parentId: 38)] : const [],
    ),
];

bool _isAccentSoft(Widget w) =>
    w is Container && w.color == AppPalette.accentSoft;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await TokenStorage.instance.clear();
    ApiClient.overrideForTesting(MockClient((_) async => _ok(_thread())));
    await AuthSession.instance.logout();
  });

  Future<void> openSheet(WidgetTester tester, {int? highlight}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showCommentsSheet(
                context,
                videoId: '1',
                initialCount: 40,
                highlightCommentId: highlight,
              ),
              child: const Text('mở'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
  }

  double screenHeight(WidgetTester tester) =>
      tester.view.physicalSize.height / tester.view.devicePixelRatio;

  testWidgets('không có highlight thì bình luận cuối chưa được dựng', (tester) async {
    await openSheet(tester);

    expect(find.text('bình luận số 38'), findsNothing);
  });

  testWidgets('cuộn tới bình luận gốc ở cuối và tô nổi nó', (tester) async {
    await openSheet(tester, highlight: 38);

    final top = tester.getTopLeft(find.text('bình luận số 38')).dy;
    expect(top, greaterThan(0));
    expect(top, lessThan(screenHeight(tester)));
    expect(find.byWidgetPredicate(_isAccentSoft), findsOneWidget);
  });

  testWidgets('cuộn tới phản hồi và chỉ tô nổi đúng phản hồi đó', (tester) async {
    await openSheet(tester, highlight: 380);

    final top = tester.getTopLeft(find.text('phản hồi cuối')).dy;
    expect(top, greaterThan(0));
    expect(top, lessThan(screenHeight(tester)));
    expect(find.byWidgetPredicate(_isAccentSoft), findsOneWidget);
  });

  testWidgets('nền tô nổi tự tắt sau vài giây', (tester) async {
    await openSheet(tester, highlight: 38);
    expect(find.byWidgetPredicate(_isAccentSoft), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));

    expect(find.byWidgetPredicate(_isAccentSoft), findsNothing);
  });

  testWidgets('bình luận không còn tồn tại thì không tô nổi gì và không lỗi', (tester) async {
    await openSheet(tester, highlight: 9999);

    expect(find.text('bình luận số 1'), findsOneWidget);
    expect(find.byWidgetPredicate(_isAccentSoft), findsNothing);
  });
}
