import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/features/profile/domain/models/topic_model.dart';
import 'package:frontend/features/video/data/hashtag_service.dart';
import 'package:frontend/features/video/domain/hashtag_rules.dart';
import 'package:frontend/features/video/presentation/widgets/video_classification_fields.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _FakeHashtagService extends HashtagService {
  _FakeHashtagService(this.results) : super(api: ApiClient.instance);

  final List<String> results;
  final queries = <String>[];

  @override
  Future<List<String>> suggest(String query) async {
    queries.add(query);
    return results;
  }
}

void main() {
  setUpAll(() {
    ApiClient.overrideForTesting(MockClient(
      (_) async => http.Response(jsonEncode({'status': 200, 'data': []}), 200),
    ));
  });

  const topics = [
    TopicModel(id: 1, name: 'Anime'),
    TopicModel(id: 2, name: 'Ẩm thực'),
    TopicModel(id: 3, name: 'Du lịch'),
    TopicModel(id: 4, name: 'Công việc'),
  ];

  late Set<int> topicIds;
  late List<String> hashtags;
  late GlobalKey<VideoClassificationFieldsState> key;

  Future<void> pump(WidgetTester tester, {List<String> suggestions = const []}) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: StatefulBuilder(
            builder: (context, setState) => VideoClassificationFields(
              key: key,
              topics: topics,
              selectedTopicIds: topicIds,
              onTopicsChanged: (ids) => setState(() => topicIds = ids),
              hashtags: hashtags,
              onHashtagsChanged: (tags) => setState(() => hashtags = tags),
              hashtagService: _FakeHashtagService(suggestions),
            ),
          ),
        ),
      ),
    ));
  }

  setUp(() {
    topicIds = {};
    hashtags = [];
    key = GlobalKey();
  });

  group('hashtag_rules', () {
    test('chuẩn hoá bỏ dấu # và viết thường, giữ dấu tiếng Việt', () {
      expect(normalizeHashtag('  #Anime '), 'anime');
      expect(normalizeHashtag('＃ĂnUống'), 'ănuống');
      expect(normalizeHashtag('##n5'), 'n5');
    });

    test('hợp lệ gồm chữ của mọi ngôn ngữ, số, gạch dưới', () {
      expect(isValidHashtag('日本語_n5'), isTrue);
      expect(isValidHashtag('ănuống'), isTrue);
      expect(isValidHashtag('c++'), isFalse);
      expect(isValidHashtag(''), isFalse);
      expect(isValidHashtag('a' * (maxHashtagLength + 1)), isFalse);
    });
  });

  testWidgets('chọn nhiều chủ đề, tối đa 3 và báo khi vượt', (tester) async {
    await pump(tester);

    for (final name in ['Anime', 'Ẩm thực', 'Du lịch']) {
      await tester.tap(find.text(name));
      await tester.pump();
    }
    expect(topicIds, {1, 2, 3});

    await tester.tap(find.text('Công việc'));
    await tester.pump();
    expect(topicIds, {1, 2, 3});
    expect(find.text('Chỉ được chọn tối đa 3 chủ đề.'), findsOneWidget);

    await tester.tap(find.text('Anime'));
    await tester.pump();
    expect(topicIds, {2, 3});
    expect(find.text('Chỉ được chọn tối đa 3 chủ đề.'), findsNothing);
  });

  testWidgets('dấu cách và dấu phẩy kết thúc một thẻ, ô nhập giữ phần đang gõ dở', (tester) async {
    await pump(tester);

    await tester.enterText(find.byType(TextField), '#Anime, tokyo mo');
    await tester.pump();

    expect(hashtags, ['anime', 'tokyo']);
    expect(find.text('mo'), findsOneWidget);
    expect(find.text('#anime'), findsOneWidget);
  });

  testWidgets('thẻ trùng không thêm lần hai', (tester) async {
    hashtags = ['anime'];
    await pump(tester);

    await tester.enterText(find.byType(TextField), '#ANIME ');
    await tester.pump();

    expect(hashtags, ['anime']);
  });

  testWidgets('quá 5 hashtag thì báo lỗi và giữ chữ đang gõ', (tester) async {
    hashtags = ['a', 'b', 'c', 'd', 'e'];
    await pump(tester);

    await tester.enterText(find.byType(TextField), 'f ');
    await tester.pump();

    expect(hashtags, hasLength(5));
    expect(find.text('Chỉ được gắn tối đa 5 hashtag.'), findsOneWidget);
  });

  testWidgets('bấm xoá trên chip để bỏ hashtag', (tester) async {
    hashtags = ['anime', 'tokyo'];
    await pump(tester);

    await tester.tap(find.byIcon(Icons.clear).first);
    await tester.pump();

    expect(hashtags, ['tokyo']);
  });

  testWidgets('chọn gợi ý thêm thẻ và xoá chữ đang gõ', (tester) async {
    await pump(tester, suggestions: ['tokyo', 'tokyo_n5']);

    await tester.enterText(find.byType(TextField), 'tok');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    expect(find.text('#tokyo_n5'), findsOneWidget);

    await tester.tap(find.text('#tokyo_n5'));
    await tester.pump();

    expect(hashtags, ['tokyo_n5']);
    expect(find.text('tok'), findsNothing);
  });

  testWidgets('commitPending thêm chữ đang gõ dở, chữ sai trả false', (tester) async {
    await pump(tester);

    await tester.enterText(find.byType(TextField), 'tokyo');
    await tester.pump();
    expect(key.currentState!.commitPending(), isTrue);
    await tester.pump();
    expect(hashtags, ['tokyo']);

    await tester.enterText(find.byType(TextField), 'c++');
    await tester.pump();
    expect(key.currentState!.commitPending(), isFalse);
    await tester.pump();
    expect(hashtags, ['tokyo']);
  });

  testWidgets('không có danh sách chủ đề thì vẫn nhập được hashtag', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: VideoClassificationFields(
          topics: const [],
          selectedTopicIds: const {},
          onTopicsChanged: (_) {},
          hashtags: const [],
          onHashtagsChanged: (_) {},
          hashtagService: _FakeHashtagService(const []),
        ),
      ),
    ));

    expect(find.textContaining('Chủ đề'), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
  });
}
