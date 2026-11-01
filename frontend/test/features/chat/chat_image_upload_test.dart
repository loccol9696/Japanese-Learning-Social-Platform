import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/storage/token_storage.dart';
import 'package:frontend/features/chat/data/services/chat_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _jwt() {
  String b64(Map<String, dynamic> map) =>
      base64Url.encode(utf8.encode(jsonEncode(map))).replaceAll('=', '');
  final exp = DateTime.now().add(const Duration(minutes: 30)).millisecondsSinceEpoch ~/ 1000;
  return '${b64({'alg': 'none'})}.${b64({'exp': exp})}.sig';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('imageTypeOf nhận dạng theo nội dung file', () {
    test('PNG', () {
      expect(ChatService.imageTypeOf(Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0, 0])), ('png', 'png'));
    });
    test('GIF', () {
      expect(ChatService.imageTypeOf(Uint8List.fromList([0x47, 0x49, 0x46, 0x38, 0x39])), ('gif', 'gif'));
    });
    test('WebP', () {
      final bytes = Uint8List.fromList([0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x45, 0x42, 0x50]);
      expect(ChatService.imageTypeOf(bytes), ('webp', 'webp'));
    });
    test('JPEG hoặc không nhận ra thì coi là JPEG', () {
      expect(ChatService.imageTypeOf(Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0])), ('jpeg', 'jpg'));
      expect(ChatService.imageTypeOf(Uint8List(0)), ('jpeg', 'jpg'));
    });
  });

  test('tải ảnh chat lên có khai báo loại file thật (backend từ chối application/octet-stream)', () async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await TokenStorage.instance.clear();
    await TokenStorage.instance.saveTokens(accessToken: _jwt(), refreshToken: 'r');

    String? body;
    ApiClient.overrideForTesting(MockClient((request) async {
      body = utf8.decode(request.bodyBytes, allowMalformed: true);
      return http.Response(
        jsonEncode({
          'status': 200,
          'data': {'secureUrl': 'https://res.cloudinary.com/demo/image/upload/a.png'},
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }));

    final url = await ChatService().uploadImage(
      Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 1, 2, 3]),
      'chat.jpg',
    );

    expect(url, 'https://res.cloudinary.com/demo/image/upload/a.png');
    expect(body, contains('content-type: image/png'));
    expect(body, isNot(contains('application/octet-stream')));
    expect(body, contains('filename="chat.png"'));
  });
}
