import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/chat/data/models/chat_models.dart';
import 'package:frontend/features/chat/data/services/chat_hub.dart';
import 'package:frontend/features/chat/data/services/chat_service.dart';
import 'package:frontend/features/chat/presentation/screens/chat_detail_screen.dart';
import 'package:frontend/features/chat/presentation/screens/messages_tab.dart';

const _conversation = Conversation(
  id: 7,
  otherUser: ChatUser(
    id: 2,
    username: 'hana',
    displayName: 'Hana',
    avatarUrl: '',
  ),
  lastMessage: null,
  unreadCount: 0,
  otherLastReadMessageId: null,
  canMessage: true,
  lastMessageAt: null,
);

class _FakeChatService extends ChatService {
  @override
  Future<Conversation> fetchConversation(int id) async => _conversation;

  @override
  Future<MessagePage> fetchMessages(
    int conversationId, {
    int? before,
    int? after,
    int size = 30,
  }) async => const MessagePage(messages: [], hasMore: false, nextCursor: null);
}

void main() {
  final hub = ChatHub.instance;

  setUp(() {
    hub.activeConversationId = null;
    hub.appInForeground.value = true;
    hub.messagesTabVisible.value = true;
  });

  Widget chat() => ChatDetailScreen(
    conversation: _conversation,
    service: _FakeChatService(),
  );

  Future<void> pumpInTab(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessagesTabScope(
            child: Navigator(
              onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => chat()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('mở khung chat là đang xem hội thoại đó', (tester) async {
    await pumpInTab(tester);

    expect(hub.activeConversationId, 7);
  });

  testWidgets('chuyển sang tab khác thì không còn xem, quay lại thì xem tiếp', (
    tester,
  ) async {
    await pumpInTab(tester);

    hub.messagesTabVisible.value = false;
    expect(hub.activeConversationId, isNull);

    hub.messagesTabVisible.value = true;
    expect(hub.activeConversationId, 7);
  });

  testWidgets('app vào nền thì không còn xem', (tester) async {
    await pumpInTab(tester);

    hub.appInForeground.value = false;
    expect(hub.activeConversationId, isNull);

    hub.appInForeground.value = true;
    expect(hub.activeConversationId, 7);
  });

  testWidgets('màn khác đè lên thì không còn xem, đóng lại thì xem tiếp', (
    tester,
  ) async {
    await pumpInTab(tester);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator).last);

    navigator.push(MaterialPageRoute<void>(builder: (_) => const SizedBox()));
    await tester.pumpAndSettle();
    expect(hub.activeConversationId, isNull);

    navigator.pop();
    await tester.pumpAndSettle();
    expect(hub.activeConversationId, 7);
  });

  testWidgets('chat mở ngoài tab Tin nhắn không phụ thuộc vào tab', (
    tester,
  ) async {
    hub.messagesTabVisible.value = false;
    await tester.pumpWidget(MaterialApp(home: chat()));
    await tester.pumpAndSettle();

    expect(hub.activeConversationId, 7);
  });

  testWidgets('đóng khung chat thì xoá hội thoại đang xem', (tester) async {
    await pumpInTab(tester);

    await tester.pumpWidget(const SizedBox());

    expect(hub.activeConversationId, isNull);
  });
}
