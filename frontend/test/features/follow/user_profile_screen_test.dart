import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/storage/token_storage.dart';
import 'package:frontend/features/chat/presentation/screens/chat_detail_screen.dart';
import 'package:frontend/features/follow/presentation/screens/user_profile_screen.dart';
import 'package:frontend/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _jwt() {
  String b64(Map<String, dynamic> map) =>
      base64Url.encode(utf8.encode(jsonEncode(map))).replaceAll('=', '');
  final exp =
      DateTime.now().add(const Duration(minutes: 30)).millisecondsSinceEpoch ~/
      1000;
  return '${b64({'alg': 'none'})}.${b64({'exp': exp})}.sig';
}

const _bob = {
  'id': 7,
  'username': 'bob',
  'displayName': 'Bob',
  'avatarUrl': '',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<http.Request> requests;
  late Map<String, dynamic> profile;
  late List<bool> followChanges;
  late ProfileRemoteDataSource videoSource;

  Map<String, dynamic> profileJson({
    required bool isFollowing,
    required bool isFollowedBy,
    bool isSelf = false,
  }) => {
    ..._bob,
    'bio': 'Xin chào',
    'followersCount': 10,
    'followingCount': 3,
    'likesCount': 5,
    'videosCount': 2,
    'isFollowing': isFollowing,
    'isFollowedBy': isFollowedBy,
    'isSelf': isSelf,
  };

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await TokenStorage.instance.clear();
    await TokenStorage.instance.saveTokens(
      accessToken: _jwt(),
      refreshToken: 'rt',
    );
    requests = [];
    followChanges = [];
    profile = profileJson(isFollowing: false, isFollowedBy: false);

    final client = MockClient((request) async {
      requests.add(request);
      final path = request.url.path;
      Object data = {};
      if (path == '/api/v1/users/7/public-profile') {
        data = profile;
      } else if (path == '/api/v1/users/7/videos') {
        data = {'content': []};
      } else if (path == '/api/v1/users/7/follow') {
        profile['isFollowing'] = request.method == 'POST';
      } else if (path == '/api/v1/chat/conversations' &&
          request.method == 'POST') {
        data = {'id': 99, 'otherUser': _bob, 'unreadCount': 0};
      } else if (path == '/api/v1/chat/conversations/99') {
        data = {'id': 99, 'otherUser': _bob, 'unreadCount': 0};
      } else if (path == '/api/v1/chat/conversations/99/messages') {
        data = {'content': [], 'hasMore': false, 'nextCursor': null};
      }
      return http.Response(
        jsonEncode({'status': 200, 'data': data}),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    ApiClient.overrideForTesting(client);
    videoSource = ProfileRemoteDataSourceImpl(client: client);
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    bool showMessageButton = true,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: UserProfileScreen(
          userId: 7,
          initialName: 'Bob',
          showMessageButton: showMessageButton,
          videoSource: videoSource,
          onFollowChanged: followChanges.add,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('chưa theo dõi: bấm Theo dõi gọi API, đổi nút và báo lại cho màn mở nó', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text('Theo dõi'), findsOneWidget);
    expect(find.text('Nhắn tin'), findsNothing);

    await tester.tap(find.text('Theo dõi'));
    await tester.pumpAndSettle();

    expect(
      requests.any(
        (r) => r.method == 'POST' && r.url.path == '/api/v1/users/7/follow',
      ),
      isTrue,
    );
    expect(find.text('Đang theo dõi'), findsOneWidget);
    expect(followChanges, [true]);
    // Một chiều thì chưa nhắn tin được.
    expect(find.text('Nhắn tin'), findsNothing);
  });

  testWidgets('đang theo dõi: bấm lại là bỏ theo dõi và báo lại', (tester) async {
    profile = profileJson(isFollowing: true, isFollowedBy: false);
    await pumpScreen(tester);

    await tester.tap(find.text('Đang theo dõi'));
    await tester.pumpAndSettle();

    expect(
      requests.any(
        (r) => r.method == 'DELETE' && r.url.path == '/api/v1/users/7/follow',
      ),
      isTrue,
    );
    expect(find.text('Theo dõi'), findsOneWidget);
    expect(followChanges, [false]);
  });

  testWidgets('follow lẫn nhau: hiện Bạn bè và Nhắn tin, bấm Nhắn tin vào khung chat', (
    tester,
  ) async {
    profile = profileJson(isFollowing: true, isFollowedBy: true);
    await pumpScreen(tester);

    expect(find.text('Bạn bè'), findsOneWidget);
    expect(find.text('Nhắn tin'), findsOneWidget);

    await tester.tap(find.text('Nhắn tin'));
    await tester.pumpAndSettle();

    final open = requests.singleWhere(
      (r) => r.method == 'POST' && r.url.path == '/api/v1/chat/conversations',
    );
    expect(jsonDecode(open.body), {'recipientId': 7});
    expect(find.byType(ChatDetailScreen), findsOneWidget);
    expect(find.text('Hãy gửi lời chào đến Bob 👋'), findsOneWidget);
  });

  testWidgets('mở từ chính khung chat: ẩn nút Nhắn tin dù đã follow lẫn nhau', (
    tester,
  ) async {
    profile = profileJson(isFollowing: true, isFollowedBy: true);
    await pumpScreen(tester, showMessageButton: false);

    expect(find.text('Bạn bè'), findsOneWidget);
    expect(find.text('Nhắn tin'), findsNothing);
  });

  testWidgets('trang của chính mình: không có nút theo dõi hay nhắn tin', (
    tester,
  ) async {
    profile = profileJson(isFollowing: false, isFollowedBy: false, isSelf: true);
    await pumpScreen(tester);

    expect(find.text('Theo dõi'), findsNothing);
    expect(find.text('Nhắn tin'), findsNothing);
  });
}
