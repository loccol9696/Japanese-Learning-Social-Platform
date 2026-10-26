import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/storage/token_storage.dart';
import 'package:frontend/features/follow/presentation/screens/follow_manage_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _jwt() {
  String b64(Map<String, dynamic> map) =>
      base64Url.encode(utf8.encode(jsonEncode(map))).replaceAll('=', '');
  final exp = DateTime.now()
          .add(const Duration(minutes: 30))
          .millisecondsSinceEpoch ~/
      1000;
  return '${b64({'alg': 'none'})}.${b64({'exp': exp})}.sig';
}

Map<String, dynamic> _user(
  int id,
  String name, {
  required bool isFollowing,
  required bool isFollowedBy,
}) => {
  'id': id,
  'username': name.toLowerCase(),
  'displayName': name,
  'avatarUrl': '',
  'isFollowing': isFollowing,
  'isFollowedBy': isFollowedBy,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<http.Request> requests;
  // Alice theo dõi mình, mình chưa theo dõi lại; Bob theo dõi lẫn nhau; Cara mình theo dõi một chiều.
  late List<Map<String, dynamic>> followers;
  late List<Map<String, dynamic>> following;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await TokenStorage.instance.clear();
    await TokenStorage.instance.saveTokens(
      accessToken: _jwt(),
      refreshToken: 'rt',
    );
    requests = [];
    followers = [
      _user(1, 'Alice', isFollowing: false, isFollowedBy: true),
      _user(2, 'Bob', isFollowing: true, isFollowedBy: true),
    ];
    following = [
      _user(2, 'Bob', isFollowing: true, isFollowedBy: true),
      _user(3, 'Cara', isFollowing: true, isFollowedBy: false),
    ];
    ApiClient.overrideForTesting(
      MockClient((request) async {
        requests.add(request);
        final path = request.url.path;
        Object data = {};
        if (path.endsWith('/users/me/followers')) {
          data = followers;
        } else if (path.endsWith('/users/me/following')) {
          data = following;
        } else if (path == '/api/v1/users/1/follow' && request.method == 'POST') {
          followers[0] = _user(1, 'Alice', isFollowing: true, isFollowedBy: true);
          following.add(_user(1, 'Alice', isFollowing: true, isFollowedBy: true));
        } else if (path == '/api/v1/users/3/follow' &&
            request.method == 'DELETE') {
          following.removeWhere((u) => u['id'] == 3);
        }
        return http.Response(
          jsonEncode({'status': 200, 'data': data}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: FollowManageScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets('hiện số người theo dõi bạn và số người bạn đang theo dõi', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text('Theo dõi bạn (2)'), findsOneWidget);
    expect(find.text('Đang theo dõi (2)'), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('Theo dõi lại'), findsOneWidget);
  });

  testWidgets('bấm Theo dõi lại gọi API và đổi nút thành Bạn bè', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Theo dõi lại'));
    await tester.pumpAndSettle();

    expect(
      requests.any(
        (r) => r.method == 'POST' && r.url.path == '/api/v1/users/1/follow',
      ),
      isTrue,
    );
    expect(find.text('Theo dõi lại'), findsNothing);
    expect(find.text('Đang theo dõi (3)'), findsOneWidget);
  });

  testWidgets('initialTab = 1 mở sẵn tab Đang theo dõi', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: FollowManageScreen(initialTab: 1)),
    );
    await tester.pumpAndSettle();

    // Cara chỉ có ở tab Đang theo dõi, Alice chỉ có ở tab Theo dõi bạn.
    expect(find.text('Cara'), findsOneWidget);
    expect(find.text('Alice'), findsNothing);
  });

  testWidgets('tab Đang theo dõi: bỏ theo dõi sau khi xác nhận', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Đang theo dõi (2)'));
    await tester.pumpAndSettle();
    expect(find.text('Cara'), findsOneWidget);

    await tester.tap(find.text('Bỏ theo dõi'));
    await tester.pumpAndSettle();
    // Hộp thoại xác nhận.
    expect(find.text('Bỏ theo dõi?'), findsOneWidget);
    await tester.tap(find.text('Bỏ theo dõi').last);
    await tester.pumpAndSettle();

    expect(
      requests.any(
        (r) => r.method == 'DELETE' && r.url.path == '/api/v1/users/3/follow',
      ),
      isTrue,
    );
    expect(find.text('Cara'), findsNothing);
    expect(find.text('Đang theo dõi (1)'), findsOneWidget);
  });
}
