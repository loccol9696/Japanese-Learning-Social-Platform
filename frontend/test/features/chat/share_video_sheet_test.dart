import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/storage/token_storage.dart';
import 'package:frontend/features/chat/presentation/widgets/share_video_sheet.dart';
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

  testWidgets('bảng chia sẻ chỉ có danh sách bạn: không ô xem trước video, không tuỳ chọn "Bắt đầu từ"', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await TokenStorage.instance.clear();
    await TokenStorage.instance.saveTokens(accessToken: _jwt(), refreshToken: 'r');
    ApiClient.overrideForTesting(MockClient((request) async => http.Response(
          jsonEncode({'status': 200, 'data': <dynamic>[]}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        )));

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showShareVideoSheet(context, videoId: '9'),
              child: const Text('mở'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();

    expect(find.text('Chia sẻ cho bạn bè'), findsOneWidget);
    expect(find.text('Tìm bạn bè'), findsOneWidget);
    // Không còn ô xem trước video và không có tuỳ chọn mốc thời gian.
    expect(find.byType(Image), findsNothing);
    expect(find.textContaining('Bắt đầu từ'), findsNothing);
    expect(find.byType(Switch), findsNothing);
  });
}
