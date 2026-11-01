import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/storage/token_storage.dart';
import 'package:frontend/features/flashcard/data/models/flashcard_set_model.dart';
import 'package:frontend/features/flashcard/presentation/screens/flashcard_listening_screen.dart';
import 'package:frontend/features/flashcard/presentation/widgets/streak_progress_bar.dart';
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
  const cardCount = 3;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await TokenStorage.instance.clear();
    await TokenStorage.instance.saveTokens(accessToken: _jwt(), refreshToken: 'r');
    ApiClient.overrideForTesting(MockClient((request) async {
      final Object data = request.method == 'GET' && request.url.path.endsWith('/cards')
          ? [
              for (var i = 1; i <= cardCount; i++)
                {'cardId': i, 'setId': 7, 'term': 'T$i', 'meaning': 'M$i'},
            ]
          : <String, dynamic>{};
      return http.Response(
        jsonEncode({'status': 200, 'data': data}),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }));
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: FlashcardListeningScreen(
        deck: FlashcardSetModel(setId: 7, title: 'N2', totalCards: cardCount),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> submit(WidgetTester tester, String answer) async {
    await tester.enterText(find.byType(TextField), answer);
    await tester.pump();
    await tester.tap(find.text('Kiểm tra đáp án'));
    await tester.pump();
  }

  testWidgets('sai thì hỏi lại, streak đồng bộ, hoàn thành có pháo hoa và học lại', (tester) async {
    await pumpScreen(tester);
    expect(find.byKey(const ValueKey('listening-skip')), findsOneWidget);
    expect(tester.widget<StreakProgressBar>(find.byType(StreakProgressBar)).progress, 0);

    await submit(tester, 'sai');
    expect(find.text('Đáp án đúng: T1'), findsOneWidget);
    expect(tester.widget<StreakProgressBar>(find.byType(StreakProgressBar)).progress, 0);
    await tester.pump(const Duration(milliseconds: 1700));

    await submit(tester, 'T2');
    expect(find.text('Chính xác!'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1700));
    await submit(tester, 'T3');
    await tester.pump(const Duration(milliseconds: 1700));

    expect(find.text('$cardCount / $cardCount'), findsOneWidget);
    expect(find.text('Hoàn thành bài luyện nghe!'), findsNothing);
    expect(tester.widget<StreakProgressBar>(find.byType(StreakProgressBar)).progress, 2 / cardCount);
    expect(find.byKey(const ValueKey('streak-badge')), findsOneWidget);

    await submit(tester, 'T1');
    await tester.pump(const Duration(milliseconds: 1700));
    expect(find.text('Hoàn thành bài luyện nghe!'), findsOneWidget);
    expect(find.byKey(const ValueKey('completion-fireworks')), findsOneWidget);
    expect(find.byKey(const ValueKey('listening-restart')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('listening-restart')));
    await tester.pumpAndSettle();
    expect(find.text('1 / $cardCount'), findsOneWidget);
    expect(find.text('Hoàn thành bài luyện nghe!'), findsNothing);
    expect(tester.widget<StreakProgressBar>(find.byType(StreakProgressBar)).progress, 0);
  });

  testWidgets('Không biết không tăng tiến trình và câu đó xuất hiện lại', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.byKey(const ValueKey('listening-skip')));
    await tester.pump();
    expect(find.text('Đáp án đúng: T1'), findsOneWidget);
    expect(tester.widget<StreakProgressBar>(find.byType(StreakProgressBar)).progress, 0);
    await tester.pump(const Duration(milliseconds: 1700));

    await submit(tester, 'T2');
    await tester.pump(const Duration(milliseconds: 1700));
    await submit(tester, 'T3');
    await tester.pump(const Duration(milliseconds: 1700));

    expect(find.text('$cardCount / $cardCount'), findsOneWidget);
    expect(find.text('Hoàn thành bài luyện nghe!'), findsNothing);
  });
}
