import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/storage/token_storage.dart';
import 'package:frontend/features/auth/data/auth_session.dart';
import 'package:frontend/features/chat/data/models/chat_models.dart';
import 'package:frontend/features/chat/presentation/screens/chat_detail_screen.dart';
import 'package:frontend/features/chat/presentation/widgets/chat_options_sheet.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _jwt() {
  String b64(Map<String, dynamic> map) =>
      base64Url.encode(utf8.encode(jsonEncode(map))).replaceAll('=', '');
  final exp = DateTime.now().add(const Duration(minutes: 30)).millisecondsSinceEpoch ~/ 1000;
  return '${b64({'alg': 'none'})}.${b64({'exp': exp})}.sig';
}

const _other = ChatUser(id: 5, username: 'yuukachan', displayName: 'Yuuka', avatarUrl: '');

const _conversation = Conversation(
  id: 42,
  otherUser: _other,
  lastMessage: null,
  unreadCount: 0,
  otherLastReadMessageId: null,
  canMessage: true,
  lastMessageAt: null,
);

Map<String, dynamic> get _conversationJson => {
      'id': 42,
      'otherUser': {'id': 5, 'username': 'yuukachan', 'displayName': 'Yuuka', 'avatarUrl': ''},
      'unreadCount': 0,
      'canMessage': true,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChatOptionsSheet', () {
    Future<ChatOption?> pickFrom(WidgetTester tester, String label) async {
      ChatOption? picked;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async => picked = await showChatOptionsSheet(context),
                child: const Text('mở'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('mở'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      return picked;
    }

    testWidgets('có đủ ba tuỳ chọn như thiết kế', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: ChatOptionsSheet())));

      expect(find.text('Báo cáo'), findsOneWidget);
      expect(find.text('Chặn người dùng'), findsOneWidget);
      expect(find.text('Xóa cuộc trò chuyện'), findsOneWidget);
      expect(find.byIcon(Icons.flag_outlined), findsOneWidget);
      expect(find.byIcon(Icons.block_rounded), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
    });

    testWidgets('chọn "Báo cáo" trả về đúng lựa chọn và đóng bảng', (tester) async {
      expect(await pickFrom(tester, 'Báo cáo'), ChatOption.report);
      expect(find.text('Chặn người dùng'), findsNothing);
    });

    testWidgets('chọn "Chặn người dùng"', (tester) async {
      expect(await pickFrom(tester, 'Chặn người dùng'), ChatOption.block);
    });

    testWidgets('chọn "Xóa cuộc trò chuyện"', (tester) async {
      expect(await pickFrom(tester, 'Xóa cuộc trò chuyện'), ChatOption.deleteConversation);
    });
  });

  group('ChatDetailScreen nút ba chấm', () {
    late List<http.Request> requests;

    /// [signIn] đăng nhập AuthSession thật (qua MockClient) cho các luồng yêu cầu đăng nhập như báo cáo.
    Future<void> openChat(
      WidgetTester tester, {
      bool signIn = false,
      List<Map<String, dynamic>> messages = const [],
    }) async {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});
      await TokenStorage.instance.clear();
      await TokenStorage.instance.saveTokens(accessToken: _jwt(), refreshToken: 'r');
      requests = [];
      ApiClient.overrideForTesting(MockClient((request) async {
        requests.add(request);
        final path = request.url.path;
        if (path.endsWith('/auth/login')) {
          return http.Response(
            jsonEncode({
              'status': 200,
              'data': {
                'tokenType': 'Bearer',
                'accessToken': _jwt(),
                'refreshToken': 'rt-1',
                'expiresIn': 1800,
                'user': {'id': 7, 'username': 'sakura', 'email': 'sakura@example.com'},
              },
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        final Object data = path.endsWith('/messages')
            ? {'content': messages, 'hasMore': false}
            : path.endsWith('/chat/conversations/42') && request.method == 'GET'
                ? _conversationJson
                : <String, dynamic>{};
        return http.Response(
          jsonEncode({'status': 200, 'data': data}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }));

      if (signIn) {
        await AuthSession.instance.login(email: 'sakura@example.com', password: 'secret1', rememberMe: false);
        addTearDown(AuthSession.instance.logout);
      }

      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ChatDetailScreen(conversation: _conversation)),
                ),
                child: const Text('vào chat'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('vào chat'));
      await tester.pumpAndSettle();
    }

    Future<void> chooseOption(WidgetTester tester, String label) async {
      await tester.tap(find.byKey(const ValueKey('chat-options-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    testWidgets('thanh đầu có nút ba chấm mở bảng ba tuỳ chọn', (tester) async {
      await openChat(tester);

      await tester.tap(find.byKey(const ValueKey('chat-options-button')));
      await tester.pumpAndSettle();

      expect(find.byType(ChatOptionsSheet), findsOneWidget);
    });

    testWidgets('xoá cuộc trò chuyện: hỏi xác nhận, gọi DELETE rồi quay về màn trước', (tester) async {
      await openChat(tester);

      await chooseOption(tester, 'Xóa cuộc trò chuyện');
      expect(find.text('Xóa đoạn chat với Yuuka?'), findsOneWidget);
      expect(requests.where((r) => r.method == 'DELETE'), isEmpty); // chưa xoá khi chưa xác nhận

      await tester.tap(find.text('Xóa'));
      await tester.pumpAndSettle();

      final deletes = requests.where((r) => r.method == 'DELETE').toList();
      expect(deletes, hasLength(1));
      expect(deletes.single.url.path, endsWith('/chat/conversations/42'));
      expect(find.text('vào chat'), findsOneWidget); // đã thoát khung chat
    });

    testWidgets('huỷ ở hộp thoại xác nhận thì không xoá và ở lại khung chat', (tester) async {
      await openChat(tester);

      await chooseOption(tester, 'Xóa cuộc trò chuyện');
      await tester.tap(find.text('Huỷ'));
      await tester.pumpAndSettle();

      expect(requests.where((r) => r.method == 'DELETE'), isEmpty);
      expect(find.byKey(const ValueKey('chat-options-button')), findsOneWidget);
    });

    testWidgets('chặn người dùng: xác nhận rồi gọi POST chặn trong chat', (tester) async {
      await openChat(tester);

      await chooseOption(tester, 'Chặn người dùng');
      expect(find.text('Chặn Yuuka?'), findsOneWidget);

      await tester.tap(find.text('Chặn'));
      await tester.pumpAndSettle();

      final blocks = requests.where((r) => r.method == 'POST' && r.url.path.endsWith('/chat/blocks/5'));
      expect(blocks, hasLength(1));
    });

    testWidgets('báo cáo mở bảng chọn lý do báo cáo người dùng', (tester) async {
      await openChat(tester, signIn: true);

      await chooseOption(tester, 'Báo cáo');

      expect(find.textContaining('Spam'), findsOneWidget);
    });

    Map<String, dynamic> message(int id, int senderId, String content) => {
          'id': id,
          'conversationId': 42,
          'senderId': senderId,
          'type': 'TEXT',
          'content': content,
          'createdAt': DateTime.now().toIso8601String(),
        };

    testWidgets('nhấn giữ tin của người kia báo cáo được đúng tin đó', (tester) async {
      await openChat(tester, signIn: true, messages: [message(88, 5, 'tin xấu')]);

      await tester.longPress(find.text('tin xấu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Báo cáo tin nhắn'));
      await tester.pumpAndSettle();

      expect(find.text('Báo cáo tin nhắn này'), findsOneWidget);
      await tester.tap(find.text('Quấy rối hoặc thù ghét'));
      await tester.pump();
      await tester.tap(find.text('Gửi báo cáo'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));

      final report = requests.singleWhere((r) => r.url.path.endsWith('/reports'));
      expect(jsonDecode(report.body), {
        'targetType': 'MESSAGE',
        'targetId': 88,
        'reason': 'HARASSMENT',
      });
    });

    testWidgets('tin bị kiểm duyệt gỡ hiện khác với tin tự thu hồi', (tester) async {
      await openChat(tester, messages: [
        {...message(90, 5, ''), 'recalled': true, 'removedByModeration': true},
        {...message(91, 5, ''), 'recalled': true},
      ]);

      expect(find.text(kModeratedMessageText), findsOneWidget);
      expect(find.text('Tin nhắn đã được thu hồi'), findsOneWidget);
    });

    testWidgets('tin của chính mình không có mục báo cáo', (tester) async {
      await openChat(tester, signIn: true, messages: [message(89, 7, 'tin của tôi')]);

      await tester.longPress(find.text('tin của tôi'));
      await tester.pumpAndSettle();

      expect(find.text('Sao chép'), findsOneWidget);
      expect(find.text('Báo cáo tin nhắn'), findsNothing);
    });
  });
}
