import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/constants/api_constants.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/network/api_exception.dart';
import 'package:frontend/core/storage/token_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// JWT không ký, chỉ cần claim `exp` để kiểm tra logic hết hạn phía client.
String _jwt({required Duration expiresIn}) {
  String b64(Map<String, dynamic> map) =>
      base64Url.encode(utf8.encode(jsonEncode(map))).replaceAll('=', '');
  final exp =
      DateTime.now().add(expiresIn).millisecondsSinceEpoch ~/ 1000;
  return '${b64({'alg': 'none'})}.${b64({'exp': exp})}.sig';
}

http.Response _json(int status, Object body) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

Map<String, dynamic> _tokens(String access, String refresh) => {
      'status': 200,
      'data': {
        'accessToken': access,
        'refreshToken': refresh,
        'user': {'id': 7, 'username': 'sakura', 'email': 's@example.com'},
      },
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final validAccess = _jwt(expiresIn: const Duration(minutes: 30));
  final expiredAccess = _jwt(expiresIn: const Duration(minutes: -5));

  late List<http.Request> requests;
  late int expiredCallbackCount;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await TokenStorage.instance.clear();
    requests = [];
    expiredCallbackCount = 0;
    ApiClient.onSessionExpired = () => expiredCallbackCount++;
  });

  tearDown(() => ApiClient.onSessionExpired = null);

  void useServer(http.Response Function(http.Request request) handler) {
    ApiClient.overrideForTesting(MockClient((request) async {
      requests.add(request);
      return handler(request);
    }));
  }

  group('gắn token', () {
    test('gửi Bearer access token và bóc `data` khỏi ApiResponse', () async {
      await TokenStorage.instance
          .saveTokens(accessToken: validAccess, refreshToken: 'rt-1');
      useServer((_) => _json(200, {'status': 200, 'data': {'ok': true}}));

      final data = await ApiClient.instance.get('${ApiConstants.baseUrl}/profile');

      expect(data, {'ok': true});
      expect(requests.single.headers['Authorization'], 'Bearer $validAccess');
    });

    test('withAuth=false không gửi token', () async {
      await TokenStorage.instance
          .saveTokens(accessToken: validAccess, refreshToken: 'rt-1');
      useServer((_) => _json(200, {'data': null}));

      await ApiClient.instance
          .post(ApiConstants.loginUrl, body: {'a': 1}, withAuth: false);

      expect(requests.single.headers.containsKey('Authorization'), isFalse);
    });

    test('không bao giờ gửi X-User-Id', () async {
      await TokenStorage.instance
          .saveTokens(accessToken: validAccess, refreshToken: 'rt-1');
      useServer((_) => _json(200, {'data': null}));

      await ApiClient.instance.get('${ApiConstants.baseUrl}/profile');

      expect(requests.single.headers.keys.map((k) => k.toLowerCase()),
          isNot(contains('x-user-id')));
    });
  });

  group('làm mới token', () {
    test('access token đã hết hạn: tự refresh trước khi gọi API', () async {
      await TokenStorage.instance
          .saveTokens(accessToken: expiredAccess, refreshToken: 'rt-old');
      useServer((request) {
        if (request.url.path.endsWith('/auth/refresh')) {
          expect(jsonDecode(request.body), {'refreshToken': 'rt-old'});
          return _json(200, _tokens(validAccess, 'rt-new'));
        }
        return _json(200, {'data': 'secret'});
      });

      final data = await ApiClient.instance.get('${ApiConstants.baseUrl}/profile');

      expect(data, 'secret');
      expect(requests.map((r) => r.url.path),
          [endsWith('/auth/refresh'), endsWith('/profile')]);
      expect(requests.last.headers['Authorization'], 'Bearer $validAccess');
      expect(await TokenStorage.instance.getRefreshToken(), 'rt-new');
    });

    test('bị 401: refresh một lần rồi gửi lại request', () async {
      await TokenStorage.instance
          .saveTokens(accessToken: validAccess, refreshToken: 'rt-old');
      var profileCalls = 0;
      useServer((request) {
        if (request.url.path.endsWith('/auth/refresh')) {
          return _json(200, _tokens('fresh-access', 'rt-new'));
        }
        profileCalls++;
        return profileCalls == 1
            ? _json(401, {'status': 401, 'message': 'hết hạn'})
            : _json(200, {'data': 'ok'});
      });

      final data = await ApiClient.instance.get('${ApiConstants.baseUrl}/profile');

      expect(data, 'ok');
      expect(profileCalls, 2);
      expect(requests.last.headers['Authorization'], 'Bearer fresh-access');
      expect(expiredCallbackCount, 0);
    });

    test('nhiều request cùng lúc chỉ refresh một lần', () async {
      await TokenStorage.instance
          .saveTokens(accessToken: expiredAccess, refreshToken: 'rt-old');
      useServer((request) {
        if (request.url.path.endsWith('/auth/refresh')) {
          return _json(200, _tokens(validAccess, 'rt-new'));
        }
        return _json(200, {'data': request.url.path});
      });

      await Future.wait([
        ApiClient.instance.get('${ApiConstants.baseUrl}/a'),
        ApiClient.instance.get('${ApiConstants.baseUrl}/b'),
        ApiClient.instance.get('${ApiConstants.baseUrl}/c'),
      ]);

      expect(
        requests.where((r) => r.url.path.endsWith('/auth/refresh')).length,
        1,
      );
    });

    test('refresh token bị từ chối: xoá phiên và báo hết phiên', () async {
      await TokenStorage.instance
          .saveTokens(accessToken: expiredAccess, refreshToken: 'rt-dead');
      useServer((request) {
        if (request.url.path.endsWith('/auth/refresh')) {
          return _json(401, {'status': 401, 'message': 'hết hạn'});
        }
        return _json(401, {'status': 401, 'message': 'Vui lòng đăng nhập'});
      });

      await expectLater(
        ApiClient.instance.get('${ApiConstants.baseUrl}/profile'),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 401)),
      );

      expect(await TokenStorage.instance.hasSession(), isFalse);
      expect(expiredCallbackCount, 1);
    });

    test('mất mạng khi refresh: KHÔNG xoá phiên', () async {
      await TokenStorage.instance
          .saveTokens(accessToken: expiredAccess, refreshToken: 'rt-keep');
      ApiClient.overrideForTesting(MockClient((request) async {
        throw http.ClientException('offline');
      }));

      await expectLater(
        ApiClient.instance.get('${ApiConstants.baseUrl}/profile'),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 503)),
      );

      expect(await TokenStorage.instance.hasSession(), isTrue);
      expect(expiredCallbackCount, 0);
    });

    test('bearerToken tường minh (đăng xuất) không kích hoạt refresh', () async {
      await TokenStorage.instance
          .saveTokens(accessToken: validAccess, refreshToken: 'rt-1');
      useServer((_) => _json(401, {'status': 401, 'message': 'x'}));

      await expectLater(
        ApiClient.instance.post(
          ApiConstants.logoutUrl,
          withAuth: false,
          bearerToken: 'explicit-token',
        ),
        throwsA(isA<ApiException>()),
      );

      expect(requests.single.headers['Authorization'], 'Bearer explicit-token');
      expect(requests.length, 1, reason: 'không gọi /auth/refresh');
      expect(expiredCallbackCount, 0);
    });
  });

  group('xử lý lỗi', () {
    test('lỗi validation: lấy thông báo của trường đầu tiên', () {
      expect(
        () => ApiClient.decodeResponse(_json(400, {
          'status': 400,
          'message': 'Validation failed',
          'data': {'email': 'Định dạng email không hợp lệ'},
        })),
        throwsA(isA<ApiException>()
            .having((e) => e.message, 'message', 'Định dạng email không hợp lệ')),
      );
    });

    test('thông báo mặc định theo mã lỗi khi server không trả message', () {
      for (final entry in {
        401: 'Phiên đăng nhập đã hết hạn',
        403: 'không có quyền',
        429: 'quá nhanh',
        500: 'Máy chủ',
      }.entries) {
        expect(
          () => ApiClient.decodeResponse(http.Response('', entry.key)),
          throwsA(isA<ApiException>()
              .having((e) => e.message, 'message', contains(entry.value))),
        );
      }
    });
  });
}
