import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/storage/token_storage.dart';
import 'package:frontend/core/widgets/square_add_button.dart';
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

  testWidgets('có ô tìm cuộc trò chuyện và nút + bên phải, kể cả khi hộp thư trống', (tester) async {
    await _pumpInbox(tester, const []);

    expect(find.text('Tin nhắn'), findsOneWidget);
    expect(find.text('Tìm cuộc trò chuyện...'), findsOneWidget);
    expect(find.byKey(const ValueKey('new-chat-button')), findsOneWidget);
    expect(find.text('Chưa có cuộc trò chuyện nào'), findsOneWidget);

    final field = tester.getRect(find.byKey(const ValueKey('inbox-search')));
    final button = tester.getRect(find.byType(SquareAddButton));
    expect(button.left, greaterThan(field.right));
  });

  testWidgets('gõ vào ô tìm kiếm lọc theo tên, username hoặc nội dung tin cuối', (tester) async {
    await _pumpInbox(tester, [
      _conversation(1, 'Yuuka', 'yuukachan', 'cái gì'),
      _conversation(2, 'Haruto', 'haruto99', 'Cảm ơn nhé'),
      _conversation(3, 'Mai Linh', 'mailinh', 'Video hay quá'),
    ]);
    expect(find.text('Yuuka'), findsOneWidget);
    expect(find.text('Haruto'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('inbox-search')), 'haru');
    await tester.pump();
    expect(find.text('Haruto'), findsOneWidget);
    expect(find.text('Yuuka'), findsNothing);

    await tester.enterText(find.byKey(const ValueKey('inbox-search')), 'video');
    await tester.pump();
    expect(find.text('Mai Linh'), findsOneWidget);
    expect(find.text('Haruto'), findsNothing);

    await tester.enterText(find.byKey(const ValueKey('inbox-search')), 'yuukachan');
    await tester.pump();
    expect(find.text('Yuuka'), findsOneWidget);
  });

  testWidgets('không khớp ai thì báo không tìm thấy; xoá chữ thì hiện lại đủ danh sách', (tester) async {
    await _pumpInbox(tester, [_conversation(1, 'Yuuka', 'yuukachan', 'cái gì')]);

    await tester.enterText(find.byKey(const ValueKey('inbox-search')), 'zzz');
    await tester.pump();
    expect(find.byKey(const ValueKey('inbox-no-match')), findsOneWidget);
    expect(find.text('Yuuka'), findsNothing);

    await tester.enterText(find.byKey(const ValueKey('inbox-search')), '');
    await tester.pump();
    expect(find.text('Yuuka'), findsOneWidget);
    expect(find.byKey(const ValueKey('inbox-no-match')), findsNothing);
  });

  testWidgets('nút + mở bảng "Tin nhắn mới"', (tester) async {
    await _pumpInbox(tester, [_conversation(1, 'Yuuka', 'yuukachan', 'cái gì')]);

    await tester.tap(find.byKey(const ValueKey('new-chat-button')));
    await tester.pumpAndSettle();

    expect(find.text('Tin nhắn mới'), findsOneWidget);
    expect(find.text('Tìm bạn bè'), findsOneWidget);
  });
}
