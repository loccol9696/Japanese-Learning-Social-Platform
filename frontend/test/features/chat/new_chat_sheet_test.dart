import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/chat/data/models/chat_models.dart';
import 'package:frontend/features/chat/data/services/chat_service.dart';
import 'package:frontend/features/chat/presentation/screens/new_chat_sheet.dart';

class _FakeChatService extends ChatService {
  _FakeChatService(this.contacts);

  final List<ChatUser> contacts;
  final List<int> opened = [];

  @override
  Future<List<ChatUser>> fetchContacts() async => contacts;

  @override
  Future<Conversation> openConversation(int recipientId) async {
    opened.add(recipientId);
    return Conversation(
      id: 99,
      otherUser: contacts.firstWhere((c) => c.id == recipientId),
      lastMessage: null,
      unreadCount: 0,
      otherLastReadMessageId: null,
      canMessage: true,
      lastMessageAt: null,
    );
  }
}

const _sakura = ChatUser(id: 1, username: 'sakura', displayName: 'Sakura', avatarUrl: '');
const _taro = ChatUser(id: 2, username: 'taro', displayName: 'Taro', avatarUrl: '');

void main() {
  /// Mở sheet bằng nút bấm để kiểm tra cả giá trị trả về khi đóng.
  Future<Future<Conversation?> Function()> pumpHost(WidgetTester tester, _FakeChatService service) async {
    Conversation? result;
    var done = false;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                result = await showModalBottomSheet<Conversation>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => NewChatSheet(service: service),
                );
                done = true;
              },
              child: const Text('mở'),
            ),
          ),
        ),
      ),
    ));
    return () async {
      await tester.pumpAndSettle();
      return done ? result : null;
    };
  }

  testWidgets('hiện tiêu đề, ô tìm kiếm và lời giải thích khi chưa có ai follow lẫn nhau', (tester) async {
    await pumpHost(tester, _FakeChatService(const []));
    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();

    expect(find.text('Tin nhắn mới'), findsOneWidget);
    expect(find.text('Tìm bạn bè'), findsOneWidget);
    expect(find.byKey(const ValueKey('new-chat-empty')), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
  });

  testWidgets('lọc theo tên, chọn một người thì đóng sheet và trả về cuộc trò chuyện', (tester) async {
    final service = _FakeChatService(const [_sakura, _taro]);
    final result = await pumpHost(tester, service);
    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();

    expect(find.text('Sakura'), findsOneWidget);
    expect(find.text('Taro'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'tar');
    await tester.pump();
    expect(find.text('Sakura'), findsNothing);

    await tester.tap(find.text('Taro'));
    final conversation = await result();

    expect(service.opened, [2]);
    expect(conversation?.id, 99);
    expect(find.text('Tin nhắn mới'), findsNothing);
  });

  testWidgets('nút đóng đóng sheet mà không chọn ai', (tester) async {
    final service = _FakeChatService(const [_sakura]);
    final result = await pumpHost(tester, service);
    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(await result(), isNull);
    expect(service.opened, isEmpty);
    expect(find.text('Tin nhắn mới'), findsNothing);
  });
}
