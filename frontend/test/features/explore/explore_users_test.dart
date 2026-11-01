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

  // ExploreService là singleton giữ ApiClient đầu tiên nó thấy, nên chỉ dựng MockClient một lần
  // và đổi dữ liệu trả về qua các biến dưới đây.
  final requests = <http.Request>[];
  var users = <Map<String, dynamic>>[];

  setUpAll(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    ApiClient.overrideForTesting(MockClient((request) async {
      requests.add(request);
      final path = request.url.path;
      Object data = {};
      if (path == '/api/v1/videos') {
        data = {'content': [], 'last': true};
      } else if (path == '/api/v1/topics') {
        data = [
          {'id': 1, 'name': 'Anime & Manga'},
        ];
      } else if (path == '/api/v1/users/search') {
        data = {'content': users, 'last': true};
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
    users = [
      {
        'id': 2,
        'username': 'tanaka',
        'displayName': 'Tanaka Sensei',
        'avatarUrl': '',
        'isFollowing': true,
        'isFollowedBy': false,
      },
    ];
  });

  Future<void> pumpExplore(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: ExploreScreen())));
    await tester.pumpAndSettle();
  }

  Future<void> typeSearch(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    // Chờ qua thời gian debounce của ô tìm kiếm (400ms).
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
  }

  Iterable<http.Request> to(String path) => requests.where((r) => r.url.path == path);

  testWidgets('không còn nút tìm người dùng bên phải ô tìm kiếm, có tag "Người dùng"', (tester) async {
    await pumpExplore(tester);

    expect(find.byTooltip('Tìm người dùng'), findsNothing);
    expect(find.byIcon(Icons.person_search_rounded), findsNothing);
    expect(find.text('Người dùng'), findsOneWidget);
    expect(find.text('Tìm theo tên, chủ đề, #hashtag...'), findsOneWidget);
  });

  testWidgets('chọn tag Người dùng: đổi gợi ý, ẩn hàng chủ đề, tìm người dùng khi gõ', (tester) async {
    await pumpExplore(tester);
    expect(find.text('Mọi chủ đề'), findsOneWidget);
    final videoRequestsBefore = to('/api/v1/videos').length;

    await tester.tap(find.text('Người dùng'));
    await tester.pumpAndSettle();

    expect(find.text('Tìm người dùng theo tên hoặc username...'), findsOneWidget);
    expect(find.text('Mọi chủ đề'), findsNothing);
    expect(find.textContaining('Nhập ít nhất 2 ký tự'), findsOneWidget);

    await typeSearch(tester, 'tana');

    expect(find.text('Tanaka Sensei'), findsOneWidget);
    expect(find.text('@tanaka'), findsOneWidget);
    expect(find.text('Đang theo dõi'), findsOneWidget);
    final search = to('/api/v1/users/search').single;
    expect(search.url.queryParameters['q'], 'tana');
    // Gõ ở chế độ người dùng không được tải lại danh sách video.
    expect(to('/api/v1/videos').length, videoRequestsBefore);
  });

  testWidgets('quay lại tag video: hiện lại chủ đề và tìm video theo cùng từ khoá', (tester) async {
    await pumpExplore(tester);
    await tester.tap(find.text('Người dùng'));
    await tester.pumpAndSettle();
    await typeSearch(tester, 'tana');
    requests.clear();

    await tester.tap(find.text('Video'));
    await tester.pumpAndSettle();

    expect(find.text('Mọi chủ đề'), findsOneWidget);
    expect(find.text('Tìm theo tên, chủ đề, #hashtag...'), findsOneWidget);
    final videos = to('/api/v1/videos').single;
    expect(videos.url.queryParameters['search'], 'tana');
    expect(videos.url.queryParameters.containsKey('topicIds'), isFalse);
    expect(find.text('Tanaka Sensei'), findsNothing);
  });

  testWidgets('không có kết quả thì báo rõ từ khoá đã tìm', (tester) async {
    users = [];
    await pumpExplore(tester);
    await tester.tap(find.text('Người dùng'));
    await tester.pumpAndSettle();

    await typeSearch(tester, 'zzz');

    expect(find.text('Không tìm thấy người dùng nào cho "zzz".'), findsOneWidget);
  });
}
