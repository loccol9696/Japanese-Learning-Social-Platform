import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/network/api_exception.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  ApiClient clientReturning(
    http.Response Function(http.Request request) handler, {
    String? token = 'jwt-123',
  }) {
    return ApiClient.withClient(
      MockClient((request) async => handler(request)),
      tokenProvider: () async => token,
    );
  }

  http.Response json(Object body, int status) => http.Response.bytes(
        utf8.encode(jsonEncode(body)),
        status,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

  test('get unwraps ApiResponse.data and sends Bearer token', () async {
    late http.Request sent;
    final api = clientReturning((request) {
      sent = request;
      return json({'status': 200, 'data': {'id': 7, 'name': 'こんにちは'}}, 200);
    });

    final data = await api.get('http://x/api/v1/users/7');

    expect(data, {'id': 7, 'name': 'こんにちは'});
    expect(sent.headers['Authorization'], 'Bearer jwt-123');
  });

  test('post does not send token unless withAuth is true', () async {
    late http.Request sent;
    final api = clientReturning((request) {
      sent = request;
      return json({'data': null}, 200);
    });

    await api.post('http://x/api/v1/auth/login', body: {'a': 1});

    expect(sent.headers.containsKey('Authorization'), isFalse);
    expect(jsonDecode(sent.body), {'a': 1});
  });

  test('error response becomes ApiException with backend message', () async {
    final api = clientReturning(
      (_) => json({'status': 403, 'message': 'Bạn không có quyền'}, 403),
    );

    await expectLater(
      api.put('http://x/api/v1/users/9', body: {}),
      throwsA(isA<ApiException>()
          .having((e) => e.statusCode, 'statusCode', 403)
          .having((e) => e.message, 'message', 'Bạn không có quyền')),
    );
  });

  test('validation errors surface the first field message', () async {
    final api = clientReturning((_) => json({
          'status': 400,
          'message': 'Validation failed',
          'data': {'title': 'Tiêu đề video không được để trống'},
        }, 400));

    await expectLater(
      api.post('http://x/api/v1/videos', body: {}),
      throwsA(isA<ApiException>().having(
          (e) => e.message, 'message', 'Tiêu đề video không được để trống')),
    );
  });

  test('non-ApiResponse errorMessage is used (speech status API)', () async {
    final api = clientReturning((_) =>
        json({'status': 'FAILED', 'errorMessage': 'GCP không khả dụng'}, 500));

    await expectLater(
      api.get('http://x/api/speech/status/abc'),
      throwsA(isA<ApiException>()
          .having((e) => e.message, 'message', 'GCP không khả dụng')),
    );
  });

  test('network failure (web ClientException) maps to 503', () async {
    final api = ApiClient.withClient(
      MockClient((_) async => throw http.ClientException('XMLHttpRequest error')),
      tokenProvider: () async => null,
    );

    await expectLater(
      api.get('http://x/api/v1/videos'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 503)),
    );
  });

  test('postMultipart sends file with auth and without JSON content-type', () async {
    late http.Request sent;
    final api = clientReturning((request) {
      sent = request;
      return json({'data': {'secureUrl': 'https://cdn/v.mp4'}}, 200);
    });

    final data = await api.postMultipart(
      'http://x/api/v1/media/upload',
      fieldName: 'file',
      bytes: Uint8List.fromList([1, 2, 3]),
      filename: 'clip.mp4',
    );

    expect(data, {'secureUrl': 'https://cdn/v.mp4'});
    expect(sent.headers['Authorization'], 'Bearer jwt-123');
    expect(sent.headers['content-type'], startsWith('multipart/form-data'));
    expect(sent.body, contains('filename="clip.mp4"'));
  });
}
