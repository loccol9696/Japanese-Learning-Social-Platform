import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/storage/token_storage.dart';
import 'package:frontend/features/home/data/video_view_tracker.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _jwt() {
  String b64(Map<String, dynamic> map) => base64Url.encode(utf8.encode(jsonEncode(map))).replaceAll('=', '');
  final exp = DateTime.now().add(const Duration(minutes: 30)).millisecondsSinceEpoch ~/ 1000;
  return '${b64({'alg': 'none'})}.${b64({'exp': exp})}.sig';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final calls = <http.Request>[];
  late http.Response Function(http.Request) handler;
  var installed = false;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await TokenStorage.instance.clear();
    await TokenStorage.instance.saveTokens(accessToken: _jwt(), refreshToken: 'r');
    calls.clear();
    VideoViewTracker.reset();
    handler = (_) => http.Response(jsonEncode({'status': 200}), 200,
        headers: {'content-type': 'application/json; charset=utf-8'});
    if (!installed) {
      installed = true;
      ApiClient.overrideForTesting(MockClient((request) async {
        calls.add(request);
        return handler(request);
      }));
    }
  });

  test('gọi POST /videos/{id}/views một lần', () async {
    await VideoViewTracker.record('42');

    expect(calls, hasLength(1));
    expect(calls.single.method, 'POST');
    expect(calls.single.url.path, endsWith('/videos/42/views'));
  });

  test('phát lại cùng video trong 30 phút thì không gọi lại', () async {
    final start = DateTime(2026, 11, 2, 10);
    await VideoViewTracker.record('42', now: start);
    await VideoViewTracker.record('42', now: start.add(const Duration(minutes: 29)));

    expect(calls, hasLength(1));
  });

  test('qua 30 phút thì tính một lượt xem mới', () async {
    final start = DateTime(2026, 11, 2, 10);
    await VideoViewTracker.record('42', now: start);
    await VideoViewTracker.record('42', now: start.add(const Duration(minutes: 31)));

    expect(calls, hasLength(2));
  });

  test('mỗi video đếm riêng', () async {
    await VideoViewTracker.record('1');
    await VideoViewTracker.record('2');

    expect(calls.map((c) => c.url.path), [endsWith('/videos/1/views'), endsWith('/videos/2/views')]);
  });

  test('gọi lỗi thì không ném lỗi ra ngoài và lần phát sau được thử lại', () async {
    handler = (_) => http.Response(jsonEncode({'status': 500, 'message': 'lỗi'}), 500,
        headers: {'content-type': 'application/json; charset=utf-8'});
    await VideoViewTracker.record('42');
    expect(calls, hasLength(1));

    handler = (_) => http.Response(jsonEncode({'status': 200}), 200,
        headers: {'content-type': 'application/json; charset=utf-8'});
    await VideoViewTracker.record('42');
    expect(calls, hasLength(2));
  });
}
