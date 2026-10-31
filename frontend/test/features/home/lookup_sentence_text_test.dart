import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/features/home/presentation/widgets/lookup_sentence_text.dart';
import 'package:frontend/features/home/presentation/widgets/ruby_subtitle_widget.dart';
import 'package:frontend/features/home/presentation/widgets/word_lookup_card.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(Object data) => http.Response(
  jsonEncode({'status': 200, 'data': data}),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    // Đóng bảng còn mở để test sau không thừa hưởng trạng thái.
    RubySubtitleWidget.dismissLookups();
  });

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    ApiClient.overrideForTesting(
      MockClient((request) async {
        if (request.url.path.endsWith('/dictionary/tokenize')) {
          final text = request.url.queryParameters['text']!;
          return _json([
            {'surface': text, 'baseForm': text, 'reading': '', 'lookupable': true},
          ]);
        }
        final word = request.url.queryParameters['word']!;
        return _json({
          'term': word,
          'reading': 'よみ',
          'meaningVi': 'nghĩa của $word',
          'meaningEn': '',
          'jlptLevel': 'N3',
          'partOfSpeech': 'Danh từ',
          'found': true,
        });
      }),
    );
  });

  testWidgets('chạm từ ở câu khác thì bảng của câu trước đóng, chỉ còn một bảng', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: const [
              LookupSentenceText(sentence: '食事', style: TextStyle(fontSize: 17)),
              SizedBox(height: 330),
              LookupSentenceText(sentence: 'そんな', style: TextStyle(fontSize: 17)),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('食事', findRichText: true));
    await tester.pumpAndSettle();
    expect(find.byType(WordLookupCard), findsOneWidget);
    expect(find.textContaining('nghĩa của 食事'), findsOneWidget);

    await tester.tap(find.text('そんな', findRichText: true));
    await tester.pumpAndSettle();
    expect(find.byType(WordLookupCard), findsOneWidget);
    expect(find.textContaining('nghĩa của そんな'), findsOneWidget);
    expect(find.textContaining('nghĩa của 食事'), findsNothing);
  });

  // Dùng câu khác test trên: DictionaryService cache kết quả tách từ giữa các test.
  testWidgets('chạm lại cùng từ thì đóng bảng', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: LookupSentenceText(sentence: '学校', style: TextStyle(fontSize: 17)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('学校', findRichText: true));
    await tester.pumpAndSettle();
    expect(find.byType(WordLookupCard), findsOneWidget);

    await tester.tap(find.text('学校', findRichText: true).first, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(WordLookupCard), findsNothing);
  });
}
