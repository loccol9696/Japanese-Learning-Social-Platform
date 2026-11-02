import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/home/data/datasources/home_remote_datasource.dart';
import 'package:frontend/features/home/domain/models/ruby_segment.dart';
import 'package:frontend/features/home/presentation/widgets/grammar_lookup_card.dart';

void main() {
  const grammar = GrammarPointInfo(
    pattern: '〜ている',
    matchedText: 'ている',
    jlptLevel: 'N5',
    meaning: 'đang',
    explanation: 'tiếp diễn',
  );

  Future<void> pumpCard(WidgetTester tester, {VoidCallback? onReport}) {
    return tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: GrammarLookupCard(
          grammar: grammar,
          sentence: '食べている',
          onClose: () {},
          onReport: onReport,
        ),
      ),
    ));
  }

  testWidgets('bảng ngữ pháp có nút báo cáo khi được truyền hàm xử lý', (tester) async {
    var reported = 0;
    await pumpCard(tester, onReport: () => reported++);

    await tester.tap(find.text('Báo cáo'));

    expect(reported, 1);
  });

  testWidgets('không truyền hàm xử lý thì không có nút báo cáo', (tester) async {
    await pumpCard(tester);

    expect(find.text('Báo cáo'), findsNothing);
  });

  test('mẫu không có pattern thì báo cáo theo matchedText', () {
    const noPattern = GrammarPointInfo(
      pattern: '',
      matchedText: 'ので',
      jlptLevel: '',
      meaning: '',
      explanation: '',
    );

    expect(grammar.reportKey, '〜ている');
    expect(noPattern.reportKey, 'ので');
  });

  test('cue giữ vị trí trong JSON gốc dù câu lỗi trước đó bị bỏ qua', () {
    final post = HomeRemoteDataSourceImpl().toVideoPost({
      'id': 1,
      'title': 't',
      'subtitles': jsonEncode([
        {'text': '', 'start': 0, 'end': 1},
        {'text': 'こんにちは', 'translation': 'Xin chào', 'start': 1, 'end': 2},
      ]),
    });

    expect(post.subtitleCues, hasLength(1));
    expect(post.subtitleCues.single.sourceIndex, 1);
  });
}
