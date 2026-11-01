import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/storage/token_storage.dart';
import 'package:frontend/features/profile/domain/models/topic_model.dart';
import 'package:frontend/features/profile/domain/models/user_profile_model.dart';
import 'package:frontend/features/profile/domain/repositories/profile_repository.dart';
import 'package:frontend/features/profile/presentation/screens/profile_screen.dart';
import 'package:frontend/features/video/domain/models/user_video_model.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Repository implements ProfileRepository {
  @override
  Future<UserProfileModel> getProfile({int? userId}) async =>
      const UserProfileModel(
        id: 1,
        username: 'yamada_san',
        displayName: 'Yamada Kenji',
        currentLevel: 'N3',
        followersCount: 120,
        followingCount: 45,
        likesCount: 950,
      );

  @override
  Future<List<TopicModel>> getTopics() async => [];

  @override
  Future<UserProfileModel> updateProfile(
    UserProfileModel profile, {
    int? userId,
  }) async => profile;

  @override
  Future<List<UserVideoModel>> getUserVideos({int? userId}) async => [];

  @override
  Future<List<UserVideoModel>> getMyVideosStatus() async => [];

  @override
  Future<List<UserVideoModel>> getLikedVideos() async => [];

  @override
  Future<List<UserVideoModel>> getSavedVideos() async => [];

  @override
  Future<List<UserVideoModel>> getModerationVideos({
    String status = 'PENDING',
  }) async => [];

  @override
  Future<void> approveVideo(int videoId) async {}

  @override
  Future<void> rejectVideo(int videoId, String reason) async {}
}

String _jwt() {
  String b64(Map<String, dynamic> map) =>
      base64Url.encode(utf8.encode(jsonEncode(map))).replaceAll('=', '');
  final exp =
      DateTime.now().add(const Duration(minutes: 30)).millisecondsSinceEpoch ~/
      1000;
  return '${b64({'alg': 'none'})}.${b64({'exp': exp})}.sig';
}

Map<String, dynamic> _user(int id, String name, {required bool following}) => {
  'id': id,
  'username': name.toLowerCase(),
  'displayName': name,
  'avatarUrl': '',
  'isFollowing': following,
  'isFollowedBy': !following,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await TokenStorage.instance.clear();
    await TokenStorage.instance.saveTokens(
      accessToken: _jwt(),
      refreshToken: 'rt',
    );
    ApiClient.overrideForTesting(
      MockClient((request) async {
        final path = request.url.path;
        Object data = {};
        if (path.endsWith('/users/me/followers')) {
          data = [_user(1, 'Alice', following: false)];
        } else if (path.endsWith('/users/me/following')) {
          data = [_user(3, 'Cara', following: true)];
        }
        return http.Response(
          jsonEncode({'status': 200, 'data': data}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
  });

  testWidgets(
    'bấm số follower / đang follow mở đúng tab của màn Quản lý theo dõi',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ProfileScreen(repository: _Repository())),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('đang follow'));
      await tester.pumpAndSettle();
      // Tab "Đang theo dõi" mở sẵn: có Cara, chưa render danh sách của Alice.
      expect(find.text('Cara'), findsOneWidget);
      expect(find.text('Alice'), findsNothing);

      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('follower'));
      await tester.pumpAndSettle();
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Cara'), findsNothing);
    },
  );
}
