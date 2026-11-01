import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/constants/api_constants.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/network/api_exception.dart';
import 'package:frontend/core/storage/token_storage.dart';
import 'package:frontend/features/auth/data/auth_session.dart';
import 'package:frontend/features/auth/data/services/auth_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _jwt(Duration expiresIn) {
  String b64(Map<String, dynamic> map) =>
      base64Url.encode(utf8.encode(jsonEncode(map))).replaceAll('=', '');
  final exp = DateTime.now().add(expiresIn).millisecondsSinceEpoch ~/ 1000;
  return '${b64({'alg': 'none'})}.${b64({'exp': exp})}.sig';
}

http.Response _json(int status, Object body) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

final _loginOk = {
  'status': 200,
  'data': {
    'tokenType': 'Bearer',
    'accessToken': _jwt(const Duration(minutes: 30)),
    'refreshToken': 'rt-1',
    'expiresIn': 1800,
    'user': {'id': 7, 'username': 'sakura', 'email': 'sakura@example.com'},
  },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<http.Request> requests;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await TokenStorage.instance.clear();
    await AuthSession.instance.logout();
    requests = [];
  });

  void useServer(http.Response Function(http.Request request) handler) {
    ApiClient.overrideForTesting(MockClient((request) async {
      requests.add(request);
      return handler(request);
    }));
  }

  test('đăng nhập: chuẩn hoá email, lưu token, chuyển sang authenticated', () async {
    useServer((_) => _json(200, _loginOk));

    await AuthSession.instance.login(
      email: '  Sakura@Example.COM ',
      password: 'secret1',
      rememberMe: true,
    );

    expect(jsonDecode(requests.single.body)['usernameOrEmail'], 'sakura@example.com');
    expect(requests.single.headers.containsKey('Authorization'), isFalse);
    expect(AuthSession.instance.status, AuthStatus.authenticated);
    expect(AuthSession.instance.user?.username, 'sakura');
    expect(await TokenStorage.instance.getRefreshToken(), 'rt-1');
    expect(await TokenStorage.instance.getSavedEmail(), 'sakura@example.com');
  });

  test('đăng nhập sai: ném ApiException, không lưu gì', () async {
    useServer((_) => _json(401, {'status': 401, 'message': 'Email hoặc mật khẩu không chính xác'}));

    await expectLater(
      AuthSession.instance.login(email: 'a@b.co', password: 'x', rememberMe: false),
      throwsA(isA<ApiException>()
          .having((e) => e.statusCode, 'statusCode', 401)),
    );

    expect(await TokenStorage.instance.hasSession(), isFalse);
    expect(AuthSession.instance.isAuthenticated, isFalse);
  });

  test('đăng xuất: thu hồi trên server rồi xoá phiên cục bộ', () async {
    useServer((request) => request.url.path.endsWith('/auth/login')
        ? _json(200, _loginOk)
        : _json(200, {'status': 200, 'data': null}));
    await AuthSession.instance
        .login(email: 'sakura@example.com', password: 'secret1', rememberMe: true);
    requests.clear();

    await AuthSession.instance.logout();

    final logout = requests.single;
    expect(logout.url.toString(), ApiConstants.logoutUrl);
    expect(jsonDecode(logout.body), {'refreshToken': 'rt-1'});
    expect(logout.headers['Authorization'], startsWith('Bearer '));
    expect(await TokenStorage.instance.hasSession(), isFalse);
    expect(await TokenStorage.instance.getUserData(), isNull);
    expect(AuthSession.instance.status, AuthStatus.unauthenticated);
  });

  test('đăng xuất vẫn thành công khi server không phản hồi', () async {
    useServer((request) => _json(200, _loginOk));
    await AuthSession.instance
        .login(email: 'sakura@example.com', password: 'secret1', rememberMe: true);
    ApiClient.overrideForTesting(MockClient((_) async => throw http.ClientException('offline')));

    await AuthSession.instance.logout();

    expect(await TokenStorage.instance.hasSession(), isFalse);
    expect(AuthSession.instance.isAuthenticated, isFalse);
  });

  group('khôi phục phiên khi mở app', () {
    test('không có phiên -> chưa đăng nhập', () async {
      useServer((_) => _json(200, _loginOk));
      expect(await AuthSession.instance.restore(isAppLaunch: true), isFalse);
      expect(requests, isEmpty);
    });

    test('có phiên + "Ghi nhớ đăng nhập" -> vào thẳng', () async {
      useServer((_) => _json(200, _loginOk));
      await AuthSession.instance
          .login(email: 'sakura@example.com', password: 'secret1', rememberMe: true);
      requests.clear();

      expect(await AuthSession.instance.restore(isAppLaunch: true), isTrue);
      expect(AuthSession.instance.user?.id, 7);
    });

    test('có phiên nhưng không "Ghi nhớ" -> đăng xuất khi mở app', () async {
      useServer((request) => request.url.path.endsWith('/auth/login')
          ? _json(200, _loginOk)
          : _json(200, {'data': null}));
      await AuthSession.instance
          .login(email: 'sakura@example.com', password: 'secret1', rememberMe: false);

      expect(await AuthSession.instance.restore(isAppLaunch: true), isFalse);
      expect(await TokenStorage.instance.hasSession(), isFalse);
    });

    test('sau khi vừa đăng nhập (không phải mở app) -> giữ phiên dù không "Ghi nhớ"', () async {
      useServer((_) => _json(200, _loginOk));
      await AuthSession.instance
          .login(email: 'sakura@example.com', password: 'secret1', rememberMe: false);

      expect(await AuthSession.instance.restore(isAppLaunch: false), isTrue);
    });
  });

  test('phiên hết hạn giữa chừng: phát sự kiện sessionExpired', () async {
    useServer((request) {
      if (request.url.path.endsWith('/auth/login')) return _json(200, _loginOk);
      return _json(401, {'status': 401, 'message': 'hết hạn'});
    });
    await AuthSession.instance
        .login(email: 'sakura@example.com', password: 'secret1', rememberMe: true);

    final expired = Completer<void>();
    final subscription = AuthSession.instance.sessionExpired.listen((_) {
      if (!expired.isCompleted) expired.complete();
    });

    await expectLater(
      ApiClient.instance.get('${ApiConstants.baseUrl}/profile'),
      throwsA(isA<ApiException>()),
    );
    await expired.future.timeout(const Duration(seconds: 2));

    expect(AuthSession.instance.status, AuthStatus.unauthenticated);
    expect(await TokenStorage.instance.hasSession(), isFalse);
    await subscription.cancel();
  });

  group('AuthService', () {
    test('quên mật khẩu / đặt lại mật khẩu gọi đúng API, chuẩn hoá email', () async {
      useServer((_) => _json(200, {'status': 200, 'data': null}));

      await AuthService.instance.forgotPassword(email: ' Sakura@Example.com');
      await AuthService.instance.resetPassword(
        email: 'Sakura@Example.com',
        otp: ' 123456 ',
        newPassword: 'NewPass1!',
      );

      expect(requests[0].url.toString(), ApiConstants.forgotPasswordUrl);
      expect(jsonDecode(requests[0].body), {'email': 'sakura@example.com'});
      expect(requests[1].url.toString(), ApiConstants.resetPasswordUrl);
      expect(jsonDecode(requests[1].body), {
        'email': 'sakura@example.com',
        'otp': '123456',
        'newPassword': 'NewPass1!',
      });
      expect(requests.every((r) => !r.headers.containsKey('Authorization')), isTrue);
    });

    test('đổi mật khẩu lưu cặp token mới của thiết bị này', () async {
      useServer((request) => request.url.path.endsWith('/auth/login')
          ? _json(200, _loginOk)
          : _json(200, {
              'status': 200,
              'data': {
                'accessToken': _jwt(const Duration(minutes: 30)),
                'refreshToken': 'rt-after-change',
                'user': {'id': 7, 'username': 'sakura', 'email': 'sakura@example.com'},
              },
            }));
      await AuthSession.instance
          .login(email: 'sakura@example.com', password: 'secret1', rememberMe: true);

      await AuthService.instance
          .changePassword(oldPassword: 'secret1', newPassword: 'NewPass1!');

      expect(await TokenStorage.instance.getRefreshToken(), 'rt-after-change');
    });
  });

  test('đăng nhập Google: gửi idToken tới /auth/google, lưu phiên và chuyển sang authenticated', () async {
    useServer((request) => _json(200, _loginOk));

    final response = await AuthSession.instance.loginWithGoogle('google-id-token');

    expect(requests.single.url.toString(), ApiConstants.googleLoginUrl);
    expect(requests.single.method, 'POST');
    expect(jsonDecode(requests.single.body), {'idToken': 'google-id-token'});
    expect(requests.single.headers.containsKey('Authorization'), isFalse);
    expect(response.user?.username, 'sakura');
    expect(AuthSession.instance.isAuthenticated, isTrue);
    expect(await TokenStorage.instance.getRefreshToken(), 'rt-1');
  });

  test('đăng nhập Google bị từ chối thì ném ApiException và không đăng nhập', () async {
    useServer((request) => _json(401, {'status': 401, 'message': 'Phiên đăng nhập Google không hợp lệ'}));

    await expectLater(
      AuthSession.instance.loginWithGoogle('bad'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401)),
    );
    expect(AuthSession.instance.isAuthenticated, isFalse);
  });
}
