import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/chat/data/models/chat_models.dart';
import 'package:frontend/features/chat/data/services/chat_service.dart';
import 'package:frontend/features/chat/presentation/screens/chat_detail_screen.dart';
import 'package:frontend/features/chat/presentation/widgets/chat_image_viewer.dart';

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

ChatMessage _message(int id, String content) => ChatMessage(
  id: id,
  conversationId: 7,
  senderId: 2,
  type: MessageType.text,
  content: content,
  clientMsgId: 'c$id',
  createdAt: DateTime(2026, 10, 31, 9, id),
);

class _FakeChatService extends ChatService {
  _FakeChatService(this.messages);

  final List<ChatMessage> messages;
  final List<int> deleted = [];

  @override
  Future<void> deleteConversation(int conversationId) async =>
      deleted.add(conversationId);

  @override
  Future<Conversation> fetchConversation(int id) async => _conversation;

  @override
  Future<MessagePage> fetchMessages(
    int conversationId, {
    int? before,
    int? after,
    int size = 30,
  }) async => MessagePage(messages: messages, hasMore: false, nextCursor: null);
}

void main() {
  Future<void> pumpChat(WidgetTester tester, List<ChatMessage> messages) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChatDetailScreen(
          conversation: _conversation,
          service: _FakeChatService(messages),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('tin chỉ hiện nội dung, chạm để xem giờ và nút tra từ', (
    tester,
  ) async {
    await pumpChat(tester, [_message(5, 'こんにちは')]);

    expect(find.text('09:05'), findsNothing);
    expect(find.text('Tra từ'), findsNothing);

    await tester.tap(find.text('こんにちは'));
    await tester.pump();
    expect(find.text('09:05'), findsOneWidget);
    expect(find.text('Tra từ'), findsOneWidget);

    await tester.tap(find.text('こんにちは'));
    await tester.pump();
    expect(find.text('09:05'), findsNothing);
  });

  testWidgets('kéo sang trái hiện giờ mọi tin, thả ra thì ẩn', (tester) async {
    await pumpChat(tester, [_message(5, 'Xin chào'), _message(1, 'Chào bạn')]);

    final gesture = await tester.startGesture(const Offset(300, 200));
    await gesture.moveBy(const Offset(-30, 0));
    await gesture.moveBy(const Offset(-30, 0));
    await tester.pump();
    expect(find.text('09:05'), findsOneWidget);
    expect(find.text('09:01'), findsOneWidget);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('09:05'), findsNothing);
  });

  testWidgets('giữ lâu tin chữ Nhật mở menu tra từ, dịch, sao chép', (
    tester,
  ) async {
    await pumpChat(tester, [_message(5, 'こんにちは')]);

    await tester.longPress(find.text('こんにちは'));
    await tester.pumpAndSettle();

    expect(find.text('Tra từ'), findsOneWidget);
    expect(find.text('Dịch'), findsOneWidget);
    expect(find.text('Sao chép'), findsOneWidget);
    expect(find.text('Thu hồi'), findsNothing);
  });

  testWidgets('cuộn lên xem tin cũ thì hiện nút về tin mới nhất', (
    tester,
  ) async {
    await pumpChat(tester, [
      for (var i = 60; i > 0; i--) _message(i, 'Tin số $i'),
    ]);
    expect(find.byTooltip('Về tin mới nhất'), findsNothing);

    await tester.drag(find.byType(ListView), const Offset(0, 600));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Về tin mới nhất'), findsOneWidget);

    await tester.tap(find.byTooltip('Về tin mới nhất'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Về tin mới nhất'), findsNothing);
  });

  testWidgets('menu xoá đoạn chat hỏi lại rồi xoá và thoát', (tester) async {
    final service = _FakeChatService([_message(5, 'Xin chào')]);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ChatDetailScreen(
                  conversation: _conversation,
                  service: service,
                ),
              ),
            ),
            child: const Text('mở chat'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('mở chat'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('chat-options-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xóa cuộc trò chuyện'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Xóa'));
    await tester.pumpAndSettle();

    expect(service.deleted, [7]);
    expect(find.byType(ChatDetailScreen), findsNothing);
  });

  group('trả lời', () {
    const replyBar = 'Đang trả lời Hana';

    testWidgets('vuốt tin sang phải thì mở thanh trả lời, bấm huỷ thì tắt', (
      tester,
    ) async {
      await pumpChat(tester, [_message(5, 'Xin chào')]);

      await tester.drag(find.text('Xin chào'), const Offset(140, 0));
      await tester.pumpAndSettle();
      expect(find.text(replyBar), findsOneWidget);
      expect(find.text('Xin chào'), findsNWidgets(2));

      await tester.tap(find.byTooltip('Huỷ trả lời'));
      await tester.pump();
      expect(find.text(replyBar), findsNothing);
    });

    testWidgets('vuốt ngắn thì không trả lời', (tester) async {
      await pumpChat(tester, [_message(5, 'Xin chào')]);

      await tester.drag(find.text('Xin chào'), const Offset(40, 0));
      await tester.pumpAndSettle();

      expect(find.text(replyBar), findsNothing);
    });

    testWidgets('kéo sang trái vẫn là xem giờ, không trả lời', (tester) async {
      await pumpChat(tester, [_message(5, 'Xin chào')]);

      await tester.drag(find.text('Xin chào'), const Offset(-140, 0));
      await tester.pumpAndSettle();

      expect(find.text(replyBar), findsNothing);
    });

    testWidgets('tin đã thu hồi không vuốt trả lời được', (tester) async {
      final recalled = ChatMessage(
        id: 5,
        conversationId: 7,
        senderId: 2,
        type: MessageType.text,
        content: '',
        recalled: true,
        clientMsgId: 'c5',
        createdAt: DateTime(2026, 10, 31, 9, 5),
      );
      await pumpChat(tester, [recalled]);

      await tester.drag(
        find.text('Tin nhắn đã được thu hồi'),
        const Offset(140, 0),
      );
      await tester.pumpAndSettle();

      expect(find.text(replyBar), findsNothing);
    });

    testWidgets('giữ lâu có mục trả lời', (tester) async {
      await pumpChat(tester, [_message(5, 'Xin chào')]);

      await tester.longPress(find.text('Xin chào'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Trả lời'));
      await tester.pumpAndSettle();

      expect(find.text(replyBar), findsOneWidget);
    });

    testWidgets('bấm trích dẫn thì cuộn tới tin gốc ở xa', (tester) async {
      const original = MessageReply(
        id: 1,
        senderId: 2,
        type: MessageType.text,
        content: 'Tin đầu tiên',
      );
      final newest = ChatMessage(
        id: 61,
        conversationId: 7,
        senderId: 2,
        type: MessageType.text,
        content: 'Trả lời tin đầu',
        replyTo: original,
        clientMsgId: 'c61',
        createdAt: DateTime(2026, 10, 31, 10, 1),
      );
      await pumpChat(tester, [
        newest,
        for (var i = 60; i > 1; i--) _message(i, 'Tin số $i'),
        _message(1, 'Tin gốc ở đầu'),
      ]);
      expect(find.text('Tin gốc ở đầu'), findsNothing);

      await tester.tap(find.text('Tin đầu tiên'));
      await tester.pumpAndSettle();

      expect(find.text('Tin gốc ở đầu'), findsOneWidget);
    });
  });

  group('xem ảnh', () {
    Future<void> pumpViewer(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const ChatImageViewer(url: ''),
              ),
              child: const Text('mở'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('mở'));
      await tester.pumpAndSettle();
      tester.takeException();
    }

    testWidgets('vuốt xuống thì đóng', (tester) async {
      await pumpViewer(tester);

      await tester.dragFrom(const Offset(400, 200), const Offset(0, 200));
      await tester.pumpAndSettle();
      tester.takeException();

      expect(find.byType(ChatImageViewer), findsNothing);
    });

    testWidgets('vuốt ngắn thì không đóng', (tester) async {
      await pumpViewer(tester);

      await tester.dragFrom(const Offset(400, 200), const Offset(0, 40));
      await tester.pumpAndSettle();
      tester.takeException();

      expect(find.byType(ChatImageViewer), findsOneWidget);
    });

    testWidgets('chạm đúp phóng to rồi không vuốt đóng được', (tester) async {
      await pumpViewer(tester);

      await tester.tapAt(const Offset(400, 300));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(const Offset(400, 300));
      await tester.pumpAndSettle();
      tester.takeException();

      final viewer = tester.widget<InteractiveViewer>(
        find.byType(InteractiveViewer),
      );
      expect(
        viewer.transformationController!.value.getMaxScaleOnAxis(),
        greaterThan(1),
      );

      await tester.dragFrom(const Offset(400, 200), const Offset(0, 200));
      await tester.pumpAndSettle();
      tester.takeException();
      expect(find.byType(ChatImageViewer), findsOneWidget);
    });
  });
}
