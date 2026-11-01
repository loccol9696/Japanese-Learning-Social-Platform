import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/storage/token_storage.dart';
import 'package:frontend/features/profile/domain/models/user_profile_model.dart';
import 'package:frontend/features/profile/domain/repositories/profile_repository.dart';
import 'package:frontend/features/profile/presentation/screens/profile_screen.dart';
import 'package:frontend/features/video/data/services/video_trash_service.dart';
import 'package:frontend/features/video/domain/models/user_video_model.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _jwt() {
  String b64(Map<String, dynamic> map) =>
      base64Url.encode(utf8.encode(jsonEncode(map))).replaceAll('=', '');
  final exp =
      DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
      1000;
  return '${b64({'alg': 'none'})}.${b64({'exp': exp})}.sig';
}

class _Repository implements ProfileRepository {
  int profileLoads = 0;
  int myVideosLoads = 0;

  @override
  Future<UserProfileModel> getProfile({int? userId}) async {
    profileLoads++;
    return const UserProfileModel(id: 1, username: 'hana', displayName: 'Hana');
  }

  @override
  Future<List<UserVideoModel>> getMyVideosStatus() async {
    myVideosLoads++;
    return const [];
  }

  @override
  Future<List<UserVideoModel>> getLikedVideos() async => const [];

  @override
  Future<List<UserVideoModel>> getSavedVideos() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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
      MockClient(
        (_) async => http.Response(
          jsonEncode({'status': 200, 'data': {}}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );
  });

  testWidgets('video vào thùng rác thì tab Cá nhân tải lại hồ sơ và danh sách', (
    tester,
  ) async {
    final repository = _Repository();
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: ProfileScreen(repository: repository))),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(repository.profileLoads, 1);
    expect(repository.myVideosLoads, 1);

    await VideoTrashService().moveToTrash(101);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(repository.profileLoads, 2);
    expect(repository.myVideosLoads, 2);
  });

  testWidgets('màn đã đóng không còn nghe video vào thùng rác', (tester) async {
    final repository = _Repository();
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: ProfileScreen(repository: repository))),
    );
    await tester.pump();
    await tester.pumpWidget(const SizedBox());

    await VideoTrashService().moveToTrash(101);
    await tester.pump();

    expect(repository.myVideosLoads, 1);
  });
}
