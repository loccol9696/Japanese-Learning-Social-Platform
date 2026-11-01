import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/storage/token_storage.dart';
import 'package:frontend/features/flashcard/data/models/flashcard_set_model.dart';
import 'package:frontend/features/flashcard/presentation/screens/flashcard_typing_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _jwt() {
  String b64(Map<String, dynamic> map) =>
      base64Url.encode(utf8.encode(jsonEncode(map))).replaceAll('=', '');
  final exp = DateTime.now().add(const Duration(minutes: 30)).millisecondsSinceEpoch ~/ 1000;
  return '${b64({'alg': 'none'})}.${b64({'exp': exp})}.sig';
}

const int _cardCount = 8;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await TokenStorage.instance.clear();
    await TokenStorage.instance.saveTokens(accessToken: _jwt(), refreshToken: 'r');
    ApiClient.overrideForTesting(MockClient((request) async {
      final Object data = request.method == 'GET' && request.url.path.endsWith('/cards')
          ? [
              for (var i = 1; i <= _cardCount; i++) {'cardId': i, 'setId': 7, 'term': 'T$i', 'meaning': 'M$i'},
            ]
          : <String, dynamic>{};
      return http.Response(
        jsonEncode({'status': 200, 'data': data}),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }));
  });

  Future<void> pumpTyping(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: FlashcardTypingScreen(deck: FlashcardSetModel(setId: 7, title: 'N2', totalCards: _cardCount)),
    ));
    await tester.pumpAndSettle();
  }

  /// Mặc định hỏi định nghĩa (M$n) và yêu cầu gõ thuật ngữ (T$n).
  Future<void> submit(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
  }

  Future<void> answer(WidgetTester tester, int question, {required bool correct}) async {
    await submit(tester, correct ? 'T$question' : 'sai');
    await tester.pump(const Duration(milliseconds: 2100)); // đủ cho tự chuyển câu, kể cả sau khi chơi lửa
  }

  testWidgets('đúng liên tiếp 2 câu: thanh tiến trình cam kèm ngọn lửa; sai thì mất chuỗi', (tester) async {
    await pumpTyping(tester);
    expect(find.byKey(const ValueKey('streak-badge')), findsNothing);

    await answer(tester, 1, correct: true);
    await answer(tester, 2, correct: true);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('progress-fill-fire')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('streak-badge')), matching: find.text('2')), findsOneWidget);

    await answer(tester, 3, correct: false);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('streak-badge')), findsNothing);
  });

  testWidgets('đúng liên tiếp 5 câu thì bùng lửa lớn', (tester) async {
    await pumpTyping(tester);

    for (var q = 1; q <= 4; q++) {
      await answer(tester, q, correct: true);
    }
    expect(find.byKey(const ValueKey('fire-celebration')), findsNothing);

    await submit(tester, 'T5');
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('fire-celebration')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2400));
    expect(find.byKey(const ValueKey('fire-celebration')), findsNothing);
  });

  testWidgets('bỏ qua một câu cũng làm đứt chuỗi', (tester) async {
    await pumpTyping(tester);
    await answer(tester, 1, correct: true);
    await answer(tester, 2, correct: true);
    await answer(tester, 3, correct: true);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('streak-badge')), findsOneWidget);

    await tester.tap(find.text('Không biết'));
    await tester.pump(const Duration(milliseconds: 2100));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const ValueKey('streak-badge')), findsNothing);
  });
}
