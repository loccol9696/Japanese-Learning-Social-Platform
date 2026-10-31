import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/storage/token_storage.dart';
import 'package:frontend/features/explore/presentation/explore_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final requests = <http.Request>[];

  setUpAll(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    ApiClient.overrideForTesting(MockClient((request) async {
      requests.add(request);
      Object data = {'content': [], 'last': true};
      if (request.url.path == '/api/v1/topics') {
        data = [
          {'id': 1, 'name': 'Anime & Manga'},
          {'id': 2, 'name': 'Ẩm thực Nhật Bản'},
        ];
      }
      return http.Response(
        jsonEncode({'status': 200, 'data': data}),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }));
  });

  setUp(() async {
    await TokenStorage.instance.clear();
    requests.clear();
  });

  Future<void> pumpExplore(WidgetTester tester, [ExploreScreen screen = const ExploreScreen()]) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: screen)));
    await tester.pumpAndSettle();
  }

  Future<void> typeSearch(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  Map<String, String> lastVideoQuery() =>
      requests.lastWhere((r) => r.url.path == '/api/v1/videos').url.queryParameters;

  testWidgets('từ khoá, chủ đề và trình độ được gửi cùng nhau', (tester) async {
    await pumpExplore(tester);

    await typeSearch(tester, 'tokyo');
    await tap(tester, 'Anime & Manga');
    await tap(tester, 'N3');

    final query = lastVideoQuery();
    expect(query['search'], 'tokyo');
    expect(query['topicIds'], '1');
    expect(query['jlptLevel'], 'N3');
    // Chọn bộ lọc không được xoá chữ người dùng đã gõ.
    expect(find.text('tokyo'), findsOneWidget);
  });

  testWidgets('gõ từ khoá không làm mất chủ đề đang chọn', (tester) async {
    await pumpExplore(tester);
    await tap(tester, 'Anime & Manga');

    await typeSearch(tester, 'tokyo');

    expect(lastVideoQuery()['topicIds'], '1');
  });

  testWidgets('chọn nhiều chủ đề, bấm lại để bỏ, "Mọi chủ đề" xoá hết', (tester) async {
    await pumpExplore(tester);

    await tap(tester, 'Anime & Manga');
    await tap(tester, 'Ẩm thực Nhật Bản');
    expect(lastVideoQuery()['topicIds'], '1,2');

    await tap(tester, 'Anime & Manga');
    expect(lastVideoQuery()['topicIds'], '2');

    await tap(tester, 'Mọi chủ đề');
    expect(lastVideoQuery().containsKey('topicIds'), isFalse);
  });

  testWidgets('bấm lại trình độ đang chọn để bỏ lọc', (tester) async {
    await pumpExplore(tester);

    await tap(tester, 'N5');
    expect(lastVideoQuery()['jlptLevel'], 'N5');

    await tap(tester, 'N5');
    expect(lastVideoQuery().containsKey('jlptLevel'), isFalse);
  });

  testWidgets('chọn trình độ không làm mất cách sắp xếp', (tester) async {
    await pumpExplore(tester);
    await tap(tester, 'Thịnh hành');
    await tap(tester, 'Mới nhất');
    expect(lastVideoQuery()['sort'], 'createdAt,desc');

    await tap(tester, 'N2');

    expect(lastVideoQuery()['sort'], 'createdAt,desc');
    expect(lastVideoQuery()['jlptLevel'], 'N2');
  });

  testWidgets('có từ khoá thì mặc định Liên quan, xoá từ khoá quay về Thịnh hành', (tester) async {
    await pumpExplore(tester);
    expect(lastVideoQuery()['sort'], 'viewCount,desc');
    expect(find.text('Thịnh hành'), findsOneWidget);

    await typeSearch(tester, 'tokyo');
    expect(lastVideoQuery()['sort'], 'relevance');
    expect(find.text('Liên quan'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(lastVideoQuery()['sort'], 'viewCount,desc');
    expect(find.text('Thịnh hành'), findsOneWidget);
  });

  testWidgets('không có từ khoá thì menu sắp xếp không có Liên quan', (tester) async {
    await pumpExplore(tester);

    await tester.tap(find.byTooltip('Sắp xếp'));
    await tester.pumpAndSettle();

    expect(find.text('Liên quan'), findsNothing);
    expect(find.text('Mới nhất'), findsOneWidget);
  });

  testWidgets('tab Người dùng ẩn bộ lọc video', (tester) async {
    await pumpExplore(tester);

    await tap(tester, 'Người dùng');

    expect(find.text('N5'), findsNothing);
    expect(find.text('Mọi chủ đề'), findsNothing);
    expect(find.byTooltip('Sắp xếp'), findsNothing);
  });

  testWidgets('mở từ hashtag trên video: tìm sẵn và hiện trong ô tìm kiếm', (tester) async {
    await pumpExplore(tester, const ExploreScreen(showBackButton: true, initialSearch: '#anime'));

    expect(lastVideoQuery()['search'], '#anime');
    expect(find.text('#anime'), findsOneWidget);
  });

  testWidgets('mở từ chủ đề trên video: lọc sẵn chủ đề đó', (tester) async {
    await pumpExplore(tester, const ExploreScreen(showBackButton: true, initialTopicId: 2));

    expect(lastVideoQuery()['topicIds'], '2');
  });
}
