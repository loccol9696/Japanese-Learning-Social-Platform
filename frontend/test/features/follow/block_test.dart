import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/storage/token_storage.dart';
import 'package:frontend/features/follow/data/follow_models.dart';
import 'package:frontend/features/follow/data/follow_service.dart';
import 'package:frontend/features/follow/presentation/screens/blocked_users_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(Object body) => http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

/// Service giả: không đụng mạng, ghi lại lời gọi.
class _FakeFollowService implements FollowService {
  _FakeFollowService(this.blocked);

  List<BlockedUser> blocked;
  final List<int> unblocked = [];

  @override
  Future<List<BlockedUser>> fetchBlocked() async => blocked;

  @override
  Future<void> unblock(int userId) async {
    unblocked.add(userId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await TokenStorage.instance.clear();
  });

  group('PublicProfile', () {
    Map<String, dynamic> raw({bool? isBlocked}) => {
          'id': 5,
          'username': 'tanaka',
          'displayName': 'Tanaka',
          'avatarUrl': '',
          'isBlocked': ?isBlocked,
        };

    test('đọc cờ isBlocked, mặc định false', () {
      expect(PublicProfile.fromJson(raw()).isBlocked, isFalse);
      expect(PublicProfile.fromJson(raw(isBlocked: true)).isBlocked, isTrue);
    });

    test('copyWith giữ nguyên các trường không đổi', () {
      final profile = PublicProfile.fromJson({...raw(), 'isFollowing': true, 'followersCount': 3});

      final blocked = profile.copyWith(isBlocked: true, isFollowing: false, followersCount: 2);

      expect(blocked.isBlocked, isTrue);
      expect(blocked.isFollowing, isFalse);
      expect(blocked.followersCount, 2);
      expect(blocked.username, 'tanaka');
      expect(profile.copyWith().isBlocked, isFalse);
    });
  });

  group('FollowService', () {
    late List<http.Request> requests;

    setUp(() {
      requests = [];
      ApiClient.overrideForTesting(MockClient((request) async {
        requests.add(request);
        return _json({
          'data': [
            {'id': 7, 'username': 'spammer', 'displayName': '', 'avatarUrl': ''},
          ],
        });
      }));
    });

    test('gọi đúng endpoint chặn, bỏ chặn và danh sách', () async {
      final service = FollowService();

      await service.block(7);
      await service.unblock(7);
      final blocked = await service.fetchBlocked();

      expect(requests.map((r) => '${r.method} ${r.url.path}'), [
        'POST /api/v1/users/7/block',
        'DELETE /api/v1/users/7/block',
        'GET /api/v1/users/me/blocked',
      ]);
      expect(blocked.single.id, 7);
      expect(blocked.single.name, 'spammer');
    });
  });

  group('BlockedUsersScreen', () {
    List<BlockedUser> sample() => const [
          BlockedUser(id: 1, username: 'a', displayName: 'Anh A', avatarUrl: ''),
          BlockedUser(id: 2, username: 'b', displayName: '', avatarUrl: ''),
        ];

    testWidgets('hiện danh sách người đã chặn', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: BlockedUsersScreen(service: _FakeFollowService(sample())),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Anh A'), findsOneWidget);
      expect(find.text('@a'), findsOneWidget);
      // Không có tên hiển thị thì dùng username.
      expect(find.text('b'), findsOneWidget);
      expect(find.text('Bỏ chặn'), findsNWidgets(2));
    });

    testWidgets('bỏ chặn gọi server và gỡ người đó khỏi danh sách', (tester) async {
      final service = _FakeFollowService(sample());
      await tester.pumpWidget(MaterialApp(home: BlockedUsersScreen(service: service)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bỏ chặn').first);
      await tester.pumpAndSettle();

      expect(service.unblocked, [1]);
      expect(find.text('Anh A'), findsNothing);
      expect(find.text('b'), findsOneWidget);
    });

    testWidgets('trạng thái trống', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: BlockedUsersScreen(service: _FakeFollowService(const [])),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Bạn chưa chặn ai.'), findsOneWidget);
    });
  });
}
