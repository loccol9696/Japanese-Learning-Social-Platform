import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/features/flashcard/data/models/flashcard_set_model.dart';
import 'package:frontend/features/flashcard/presentation/screens/flashcard_flip_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(Object? data, [int status = 200]) => http.Response.bytes(
      utf8.encode(jsonEncode({'success': status < 400, 'message': 'Lỗi máy chủ', 'data': data})),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

final _cards = [
  {'cardId': 1, 'term': '猫', 'reading': 'ねこ', 'meaning': 'Con mèo', 'isStarred': true},
  {'cardId': 2, 'term': '犬', 'reading': 'いぬ', 'meaning': 'Con chó'},
];

void main() {
  late List<http.Request> requests;

  /// [fail] chọn request nào trả lỗi 500.
  void useApi({bool Function(http.Request req)? fail}) {
    requests = [];
    ApiClient.instanceForTest = ApiClient.withClient(
      MockClient((req) async {
        requests.add(req);
        if (fail?.call(req) ?? false) return _json(null, 500);
        return _json(req.method == 'GET' ? _cards : null);
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

  Future<void> pumpFlip(WidgetTester tester) async {
    tester.view.physicalSize = const Size(412, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(navigatorKey: navigator, home: const Text('root')));
    navigator.currentState!.push(MaterialPageRoute(
      builder: (_) => FlashcardFlipScreen(deck: FlashcardSetModel(setId: 101, title: 'N5')),
    ));
    await settle(tester);
  }

  Iterable<Map<String, dynamic>> postedBodies(String pathSuffix) => requests
      .where((r) => r.method == 'POST' && r.url.path.endsWith(pathSuffix))
      .map((r) => jsonDecode(r.body) as Map<String, dynamic>);

  testWidgets('chạm thẻ để lật, "Đã nhớ" gửi kết quả và sang thẻ kế', (tester) async {
    useApi();
    await pumpFlip(tester);
    expect(find.text('猫'), findsOneWidget);

    await tester.tapAt(const Offset(206, 450));
    await settle(tester);
    expect(find.text('Con mèo'), findsOneWidget);

    await tester.tap(find.text('Đã nhớ'));
    await settle(tester);
    expect(postedBodies('/study/answer'), [
      {'cardId': 1, 'isCorrect': true},
    ]);
    expect(find.text('犬'), findsWidgets);
  });

  testWidgets('vuốt trái đủ xa = "Chưa nhớ"; kéo ngắn thì thẻ bật về', (tester) async {
    useApi();
    await pumpFlip(tester);

    await tester.dragFrom(const Offset(206, 450), const Offset(-60, 0));
    await settle(tester);
    expect(postedBodies('/study/answer'), isEmpty);

    await tester.dragFrom(const Offset(206, 450), const Offset(-200, 0));
    await settle(tester);
    expect(postedBodies('/study/answer'), [
      {'cardId': 1, 'isCorrect': false},
    ]);
  });

  testWidgets('hết thẻ → hộp thoại hoàn thành, "Trở về" đóng màn học', (tester) async {
    useApi();
    await pumpFlip(tester);

    await tester.tap(find.text('Đã nhớ'));
    await settle(tester);
    await tester.tap(find.text('Đã nhớ'));
    await settle(tester);
    expect(find.text('Hoàn thành xuất sắc!'), findsOneWidget);

    await tester.tap(find.text('Trở về'));
    await settle(tester);
    expect(find.text('root'), findsOneWidget);
  });

  testWidgets('API lỗi khi tải thẻ → báo lỗi thay vì quay mãi', (tester) async {
    useApi(fail: (req) => req.method == 'GET');
    await pumpFlip(tester);

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('Không tải được bộ thẻ'), findsOneWidget);
  });

  testWidgets('gắn sao lỗi → hoàn tác và báo lỗi', (tester) async {
    useApi(fail: (req) => req.url.path.endsWith('/star'));
    await pumpFlip(tester);
    expect(find.byIcon(Icons.star), findsOneWidget);

    await tester.tap(find.byIcon(Icons.star));
    await settle(tester);

    expect(postedBodies('/star'), [
      {'isStarred': false},
    ]);
    expect(find.byIcon(Icons.star), findsOneWidget);
    expect(find.textContaining('Không thể cập nhật gắn sao'), findsOneWidget);
  });

  testWidgets('gửi kết quả lỗi không làm hỏng luồng học', (tester) async {
    useApi(fail: (req) => req.url.path.endsWith('/study/answer'));
    await pumpFlip(tester);

    await tester.tap(find.text('Đã nhớ'));
    await settle(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('犬'), findsWidgets);
  });
}
