import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/storage/token_storage.dart';
import 'package:frontend/features/flashcard/data/models/flashcard_set_model.dart';
import 'package:frontend/features/flashcard/presentation/screens/flashcard_quiz_screen.dart';
import 'package:frontend/features/flashcard/presentation/widgets/study_options_bottom_sheet.dart';
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

  late List<http.Request> requests;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await TokenStorage.instance.clear();
    await TokenStorage.instance.saveTokens(accessToken: _jwt(), refreshToken: 'r');
    requests = [];
    ApiClient.overrideForTesting(MockClient((request) async {
      requests.add(request);
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

  Future<void> pumpQuiz(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: FlashcardQuizScreen(
        deck: FlashcardSetModel(setId: 7, title: 'N2', totalCards: _cardCount),
        options: StudyOptions(),
      ),
    ));
    await tester.pumpAndSettle();
  }

  /// Văn bản của bốn đáp án đang hiện.
  List<String> optionTexts(WidgetTester tester) => [
        for (var i = 0; i < 4; i++)
          if (find.byKey(ValueKey('quiz-option-$i')).evaluate().isNotEmpty)
            tester
                .widget<Text>(find.descendant(of: find.byKey(ValueKey('quiz-option-$i')), matching: find.byType(Text)))
                .data!,
      ];

  /// Câu hỏi thứ [n] (1..): từ T$n, đáp án đúng M$n.
  Future<int> tapOption(WidgetTester tester, {required int question, required bool correct}) async {
    final texts = optionTexts(tester);
    final index = correct
        ? texts.indexOf('M$question')
        : texts.indexWhere((t) => t != 'M$question');
    expect(index, isNonNegative);
    await tester.tap(find.byKey(ValueKey('quiz-option-$index')));
    await tester.pump();
    return index;
  }

  Future<void> answerCorrectly(WidgetTester tester, int question) async {
    await tapOption(tester, question: question, correct: true);
    await tester.pump(const Duration(milliseconds: 2100)); // đủ cho tự chuyển câu, kể cả sau khi chơi lửa
  }

  final progress = find.text('1 / $_cardCount');

  testWidgets('bố cục như thiết kế: thẻ có nhãn "Thuật ngữ", dòng "Chọn câu trả lời", bốn đáp án, không còn "Bạn không biết?"',
      (tester) async {
    await pumpQuiz(tester);

    expect(progress, findsOneWidget);
    expect(find.text('Thuật ngữ'), findsOneWidget);
    expect(find.text('T1'), findsOneWidget);
    expect(find.text('Chọn câu trả lời'), findsOneWidget);
    expect(optionTexts(tester), hasLength(4));
    expect(find.text('Bạn không biết?'), findsNothing);
    expect(find.byKey(const ValueKey('quiz-continue')), findsNothing);
  });

  testWidgets('trả lời sai: đáp án đã chọn viền đỏ + dấu ✕, đáp án đúng có tick, hiện nút "Tiếp tục" và không tự chuyển câu',
      (tester) async {
    await pumpQuiz(tester);

    final wrong = await tapOption(tester, question: 1, correct: false);
    final texts = optionTexts(tester);
    final right = texts.indexOf('M1');

    expect(find.byKey(ValueKey('quiz-wrong-$wrong')), findsOneWidget);
    expect(find.byKey(ValueKey('quiz-correct-$right')), findsOneWidget);
    expect(find.byKey(const ValueKey('quiz-continue')), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    expect(progress, findsOneWidget); // vẫn ở câu 1

    await tester.tap(find.byKey(const ValueKey('quiz-continue')));
    await tester.pump();
    expect(find.text('2 / $_cardCount'), findsOneWidget);
    expect(find.byKey(const ValueKey('quiz-continue')), findsNothing);
    expect(find.text('T2'), findsOneWidget);
  });

  testWidgets('trả lời đúng: hiện tick, không có nút "Tiếp tục", tự chuyển sang câu sau', (tester) async {
    await pumpQuiz(tester);

    final right = await tapOption(tester, question: 1, correct: true);

    expect(find.byKey(ValueKey('quiz-correct-$right')), findsOneWidget);
    expect(find.byKey(const ValueKey('quiz-continue')), findsNothing);

    await tester.pump(const Duration(milliseconds: 1200));
    expect(find.text('2 / $_cardCount'), findsOneWidget);
  });

  testWidgets('chọn xong không chọn lại được đáp án khác', (tester) async {
    await pumpQuiz(tester);

    await tapOption(tester, question: 1, correct: false);
    final answersBefore = requests.where((r) => r.url.path.endsWith('/flashcards/study/answer')).length;
    final texts = optionTexts(tester);
    await tester.tap(find.byKey(ValueKey('quiz-option-${texts.indexOf('M1')}')));
    await tester.pump();

    expect(requests.where((r) => r.url.path.endsWith('/flashcards/study/answer')).length, answersBefore);
  });

  testWidgets('đúng liên tiếp 2 câu: thanh tiến trình đổi màu cam và hiện ngọn lửa mang số 2', (tester) async {
    await pumpQuiz(tester);
    expect(find.byKey(const ValueKey('streak-badge')), findsNothing);

    await answerCorrectly(tester, 1);
    expect(find.byKey(const ValueKey('streak-badge')), findsNothing); // mới 1 câu

    await tapOption(tester, question: 2, correct: true);
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const ValueKey('progress-fill-fire')), findsOneWidget);
    expect(find.byKey(const ValueKey('streak-badge')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('streak-badge')), matching: find.text('2')), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('trả lời sai thì mất chuỗi: ngọn lửa và màu cam biến mất', (tester) async {
    await pumpQuiz(tester);
    await answerCorrectly(tester, 1);
    await answerCorrectly(tester, 2);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('streak-badge')), findsOneWidget);

    await tapOption(tester, question: 3, correct: false);
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const ValueKey('streak-badge')), findsNothing);
    expect(find.byKey(const ValueKey('progress-fill')), findsOneWidget);
  });

  testWidgets('đúng liên tiếp 4 câu thì chưa có lửa lớn, câu thứ 5 thì bùng lên', (tester) async {
    await pumpQuiz(tester);

    for (var q = 1; q <= 4; q++) {
      await answerCorrectly(tester, q);
    }
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('fire-celebration')), findsNothing);
    expect(find.descendant(of: find.byKey(const ValueKey('streak-badge')), matching: find.text('4')), findsOneWidget);

    await tapOption(tester, question: 5, correct: true);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('fire-celebration')), findsOneWidget);

    // Sau khi chơi xong lửa tự tắt và quiz đã sang câu kế.
    await tester.pump(const Duration(milliseconds: 2200));
    expect(find.byKey(const ValueKey('fire-celebration')), findsNothing);
    expect(find.text('6 / $_cardCount'), findsOneWidget);
  });

  testWidgets('đúng 4 rồi sai rồi đúng thêm: chuỗi đếm lại từ đầu, chưa có lửa lớn', (tester) async {
    await pumpQuiz(tester);
    for (var q = 1; q <= 4; q++) {
      await answerCorrectly(tester, q);
    }
    await tapOption(tester, question: 5, correct: false);
    await tester.tap(find.byKey(const ValueKey('quiz-continue')));
    await tester.pump();

    await answerCorrectly(tester, 6);
    await answerCorrectly(tester, 7);
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const ValueKey('fire-celebration')), findsNothing);
  });

  testWidgets('trả lời sai thì gọi API ghi nhận đáp án sai', (tester) async {
    await pumpQuiz(tester);

    await tapOption(tester, question: 1, correct: false);

    final answer = requests.lastWhere((r) => r.url.path.endsWith('/flashcards/study/answer'));
    expect(jsonDecode(answer.body), {'cardId': 1, 'isCorrect': false});
  });
}
