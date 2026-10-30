import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/chat/data/models/chat_models.dart';
import 'package:frontend/features/chat/data/services/chat_service.dart';
import 'package:frontend/features/chat/presentation/screens/inbox_screen.dart';

Conversation _conversation(
  int id,
  String name, {
  int unread = 0,
  bool blockedByMe = false,
}) => Conversation(
  id: id,
  otherUser: ChatUser(
    id: id + 100,
    username: name.toLowerCase(),
    displayName: name,
    avatarUrl: '',
  ),
  lastMessage: ChatMessage(
    id: id,
    conversationId: id,
    senderId: id + 100,
    type: MessageType.text,
    content: 'Tin của $name',
    clientMsgId: 'c$id',
    createdAt: DateTime(2026, 10, 31, 9, 5),
  ),
  unreadCount: unread,
  otherLastReadMessageId: null,
  canMessage: true,
  lastMessageAt: DateTime(2026, 10, 31, 9, 5),
  blockedByMe: blockedByMe,
);

class _FakeChatService extends ChatService {
  _FakeChatService(this.conversations);

  List<Conversation> conversations;
  final List<int> blocked = [];
  final List<int> unblocked = [];
  final List<int> deleted = [];

  @override
  Future<List<Conversation>> fetchConversations() async => conversations;

  @override
  Future<void> deleteConversation(int conversationId) async {
    deleted.add(conversationId);
    conversations = conversations.where((c) => c.id != conversationId).toList();
  }

  @override
  Future<void> blockUser(int userId) async => blocked.add(userId);

  @override
  Future<void> unblockUser(int userId) async => unblocked.add(userId);
}

void main() {
  Future<_FakeChatService> pump(
    WidgetTester tester,
    List<Conversation> conversations,
  ) async {
    final service = _FakeChatService(conversations);
    await tester.pumpWidget(MaterialApp(home: InboxScreen(service: service)));
    await tester.pumpAndSettle();
    return service;
  }

  testWidgets('hiện tiêu đề, ô tìm kiếm, tên, tin cuối và số chưa đọc', (
    tester,
  ) async {
    await pump(tester, [_conversation(1, 'Hana', unread: 2)]);

    expect(find.text('Tin nhắn'), findsOneWidget);
    expect(find.text('Tìm kiếm'), findsOneWidget);
    expect(find.text('Hana'), findsOneWidget);
    expect(find.text('Tin của Hana'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('tìm theo tên, xoá ô tìm thì hiện lại đủ', (tester) async {
    await pump(tester, [_conversation(1, 'Hana'), _conversation(2, 'Kenji')]);

    await tester.enterText(find.byType(TextField), 'ken');
    await tester.pump();
    expect(find.text('Kenji'), findsOneWidget);
    expect(find.text('Hana'), findsNothing);

    await tester.enterText(find.byType(TextField), 'không có ai');
    await tester.pump();
    expect(find.text('Không tìm thấy cuộc trò chuyện nào'), findsOneWidget);

    await tester.tap(find.byTooltip('Xoá tìm kiếm'));
    await tester.pump();
    expect(find.text('Hana'), findsOneWidget);
    expect(find.text('Kenji'), findsOneWidget);
  });

  testWidgets('vuốt phải đánh dấu đã đọc và hàng vẫn còn', (tester) async {
    await pump(tester, [_conversation(1, 'Hana', unread: 2)]);

    await tester.drag(find.text('Hana'), const Offset(500, 0));
    await tester.pumpAndSettle();

    expect(find.text('2'), findsNothing);
    expect(find.text('Hana'), findsOneWidget);
  });

  testWidgets('hội thoại đã đọc không vuốt phải được', (tester) async {
    await pump(tester, [_conversation(1, 'Hana')]);

    await tester.drag(find.text('Hana'), const Offset(500, 0));
    await tester.pump();

    expect(find.text('Đã đọc'), findsNothing);
  });

  testWidgets('vuốt trái hỏi lại, huỷ thì giữ nguyên, xác nhận thì xoá', (
    tester,
  ) async {
    final service = await pump(tester, [
      _conversation(1, 'Hana'),
      _conversation(2, 'Kenji'),
    ]);

    await tester.drag(find.text('Hana'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Huỷ'));
    await tester.pumpAndSettle();
    expect(service.deleted, isEmpty);
    expect(find.text('Hana'), findsOneWidget);

    await tester.drag(find.text('Hana'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Xóa'));
    await tester.pumpAndSettle();
    expect(service.deleted, [1]);
    expect(find.text('Hana'), findsNothing);
    expect(find.text('Kenji'), findsOneWidget);
  });

  testWidgets('giữ lâu chọn chặn, có hỏi lại', (tester) async {
    final service = await pump(tester, [_conversation(1, 'Hana')]);

    await tester.longPress(find.text('Hana'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chặn'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Chặn'));
    await tester.pumpAndSettle();

    expect(service.blocked, [101]);
  });

  testWidgets('giữ lâu bỏ chặn không cần hỏi lại', (tester) async {
    final service = await pump(tester, [
      _conversation(1, 'Hana', blockedByMe: true),
    ]);

    await tester.longPress(find.text('Hana'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bỏ chặn'));
    await tester.pumpAndSettle();

    expect(service.unblocked, [101]);
  });

  testWidgets('giữ lâu chọn xoá đoạn chat', (tester) async {
    final service = await pump(tester, [_conversation(1, 'Hana')]);

    await tester.longPress(find.text('Hana'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xóa đoạn chat'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Xóa'));
    await tester.pumpAndSettle();

    expect(service.deleted, [1]);
    expect(find.text('Hana'), findsNothing);
  });

  testWidgets('giữ lâu mở menu thao tác', (tester) async {
    await pump(tester, [_conversation(1, 'Hana', unread: 1)]);

    await tester.longPress(find.text('Hana'));
    await tester.pumpAndSettle();

    expect(find.text('Đánh dấu đã đọc'), findsOneWidget);
    expect(find.text('Xem trang cá nhân'), findsOneWidget);
    expect(find.text('Chặn'), findsOneWidget);
    expect(find.text('Xóa đoạn chat'), findsOneWidget);
  });
}
