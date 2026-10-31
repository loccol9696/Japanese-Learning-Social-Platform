import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/storage/token_storage.dart';
import 'package:frontend/features/chat/presentation/screens/inbox_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _jwt() {
  String b64(Map<String, dynamic> map) =>
      base64Url.encode(utf8.encode(jsonEncode(map))).replaceAll('=', '');
  final exp = DateTime.now().add(const Duration(minutes: 30)).millisecondsSinceEpoch ~/ 1000;
  return '${b64({'alg': 'none'})}.${b64({'exp': exp})}.sig';
}

Map<String, dynamic> _conversation(int id, String name, String username, String last) => {
      'id': id,
      'otherUser': {'id': id + 100, 'username': username, 'displayName': name, 'avatarUrl': ''},
      'lastMessage': {
        'id': id,
        'conversationId': id,
        'senderId': id + 100,
        'type': 'TEXT',
        'content': last,
        'clientMsgId': '',
        'createdAt': DateTime(2026, 10, 27, 22, 46).toIso8601String(),
      },
      'unreadCount': 0,
      'canMessage': true,
      'lastMessageAt': DateTime(2026, 10, 27, 22, 46).toIso8601String(),
    };

Future<void> _pumpInbox(WidgetTester tester, List<Map<String, dynamic>> conversations) async {
  FlutterSecureStorage.setMockInitialValues({});
  SharedPreferences.setMockInitialValues({});
  await TokenStorage.instance.clear();
  await TokenStorage.instance.saveTokens(accessToken: _jwt(), refreshToken: 'r');
  ApiClient.overrideForTesting(MockClient((request) async {
    final path = request.url.path;
    final Object data = path.endsWith('/chat/conversations')
        ? {'content': conversations}
        : path.endsWith('/chat/contacts')
            ? <dynamic>[]
            : <String, dynamic>{};
    return http.Response(
      jsonEncode({'status': 200, 'data': data}),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }));
  await tester.pumpWidget(const MaterialApp(home: InboxScreen()));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Ô tìm kiếm trong hộp thư giờ là bản của dev (lọc theo tên và username); ở đây chỉ kiểm nút "Tin nhắn mới"
  // vẫn mở bảng kéo lên của nhánh này.
  testWidgets('nút "Tin nhắn mới" mở bảng "Tin nhắn mới"', (tester) async {
    await _pumpInbox(tester, [_conversation(1, 'Yuuka', 'yuukachan', 'cái gì')]);

    await tester.tap(find.byTooltip('Tin nhắn mới'));
    await tester.pumpAndSettle();

    expect(find.text('Tìm bạn bè'), findsOneWidget);
  });
}
