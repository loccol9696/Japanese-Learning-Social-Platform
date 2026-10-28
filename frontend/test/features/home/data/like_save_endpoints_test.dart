import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/storage/token_storage.dart';
import 'package:frontend/features/home/data/datasources/home_remote_datasource.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<http.Request> requests;
  late HomeRemoteDataSourceImpl dataSource;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await TokenStorage.instance.clear();
    requests = [];
    ApiClient.overrideForTesting(MockClient((request) async {
      requests.add(request);
      return http.Response(
        jsonEncode({'status': 200, 'data': null}),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }));
    dataSource = HomeRemoteDataSourceImpl();
  });

  String describe(http.Request r) => '${r.method} ${r.url.path}';

  test('thích gọi POST /likes, bỏ thích gọi DELETE /likes', () async {
    expect(await dataSource.setLiked('42', liked: true), isTrue);
    expect(await dataSource.setLiked('42', liked: false), isFalse);

    expect(requests.map(describe), [
      'POST /api/v1/videos/42/likes',
      'DELETE /api/v1/videos/42/likes',
    ]);
  });

  test('lưu gọi POST /saves, bỏ lưu gọi DELETE /saves', () async {
    expect(await dataSource.setSaved('42', saved: true), isTrue);
    expect(await dataSource.setSaved('42', saved: false), isFalse);

    expect(requests.map(describe), [
      'POST /api/v1/videos/42/saves',
      'DELETE /api/v1/videos/42/saves',
    ]);
  });

  test('gửi lại cùng một trạng thái không đảo trạng thái (idempotent)', () async {
    await dataSource.setLiked('7', liked: true);
    await dataSource.setLiked('7', liked: true);

    // Cả hai lần đều là POST /likes; server đảm bảo kết quả vẫn là "đã thích".
    expect(requests.map(describe), everyElement('POST /api/v1/videos/7/likes'));
  });

  test('không còn dùng endpoint đảo trạng thái /like và /save', () async {
    await dataSource.setLiked('9', liked: true);
    await dataSource.setSaved('9', saved: true);

    expect(requests.map((r) => r.url.path), isNot(contains('/api/v1/videos/9/like')));
    expect(requests.map((r) => r.url.path), isNot(contains('/api/v1/videos/9/save')));
  });
}
