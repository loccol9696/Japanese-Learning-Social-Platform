import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/chat/data/models/chat_models.dart';
import 'package:frontend/features/chat/presentation/chat_format.dart';

void main() {
  group('ChatMessage.fromJson', () {
    test('parses a text message', () {
      final message = ChatMessage.fromJson({
        'id': 5,
        'conversationId': 2,
        'senderId': 3,
        'type': 'TEXT',
        'content': 'こんにちは',
        'clientMsgId': 'c-1',
        'createdAt': '2026-10-24T22:01:28.9209353',
      });
      expect(message.id, 5);
      expect(message.type, MessageType.text);
      expect(message.content, 'こんにちは');
      expect(message.video, isNull);
      expect(message.status, MessageStatus.sent);
    });

    test('parses a video share with card and timestamp', () {
      final message = ChatMessage.fromJson({
        'id': 6,
        'conversationId': 2,
        'senderId': 3,
        'type': 'VIDEO_SHARE',
        'content': 'この文を聞いて',
        'videoStartMs': 12500,
        'createdAt': '2026-10-24T22:01:29',
        'video': {
          'id': 2,
          'available': true,
          'title': 'Shadowing N3',
          'duration': 60,
          'jlptLevel': 'N3',
          'creatorDisplayName': 'Tanaka Sensei',
          'creatorUsername': 'tanaka_sensei',
        },
      });
      expect(message.type, MessageType.videoShare);
      expect(message.videoStartMs, 12500);
      expect(message.video!.available, isTrue);
      expect(message.video!.creatorName, 'Tanaka Sensei');
      expect(message.previewFor(3), startsWith('Bạn: '));
      expect(message.previewFor(4), '🎬 Shadowing N3');
    });

    test('unavailable shared video falls back to a generic preview', () {
      final message = ChatMessage.fromJson({
        'id': 7,
        'conversationId': 2,
        'senderId': 3,
        'type': 'VIDEO_SHARE',
        'createdAt': '2026-10-24T22:01:29',
        'video': {'id': 9, 'available': false},
      });
      expect(message.video!.available, isFalse);
      expect(message.previewFor(4), '🎬 Video');
    });
  });

  group('Conversation', () {
    test('canMessage defaults to true and copyWith can lock it', () {
      final conversation = Conversation.fromJson({
        'id': 1,
        'otherUser': {'id': 4, 'username': 'yamada', 'displayName': ''},
        'unreadCount': 2,
      });
      expect(conversation.canMessage, isTrue);
      expect(conversation.otherUser.name, 'yamada');
      expect(conversation.copyWith(canMessage: false).canMessage, isFalse);
      expect(conversation.copyWith(unreadCount: 0).unreadCount, 0);
    });
  });

  group('MessagePage', () {
    test('keeps server order and cursor', () {
      final page = MessagePage.fromJson({
        'content': [
          {
            'id': 9,
            'conversationId': 1,
            'senderId': 1,
            'type': 'TEXT',
            'content': 'b',
            'createdAt': '2026-10-24T10:00:00',
          },
          {
            'id': 8,
            'conversationId': 1,
            'senderId': 1,
            'type': 'TEXT',
            'content': 'a',
            'createdAt': '2026-10-24T09:00:00',
          },
        ],
        'hasMore': true,
        'nextCursor': 8,
      });
      expect(page.messages.map((m) => m.id), [9, 8]);
      expect(page.hasMore, isTrue);
      expect(page.nextCursor, 8);
    });
  });

  group('chat_format', () {
    final now = DateTime(2026, 10, 24, 15, 30);

    test('conversation time: today, yesterday, this year, older', () {
      expect(
        formatConversationTime(DateTime(2026, 10, 24, 9, 5), now: now),
        '09:05',
      );
      expect(
        formatConversationTime(DateTime(2026, 10, 23, 23, 0), now: now),
        'Hôm qua',
      );
      expect(formatConversationTime(DateTime(2026, 3, 2), now: now), '02/03');
      expect(
        formatConversationTime(DateTime(2025, 12, 31), now: now),
        '31/12/2025',
      );
      expect(formatConversationTime(null, now: now), '');
    });

    test('video timestamps', () {
      expect(formatMillis(12500), '00:12');
      expect(formatMillis(125000), '02:05');
      expect(formatSeconds(75), '01:15');
    });
  });

  group('tin ảnh, thu hồi và chặn', () {
    Map<String, dynamic> message(Map<String, dynamic> extra) => {
      'id': 1,
      'conversationId': 2,
      'senderId': 3,
      'type': 'TEXT',
      'createdAt': '2026-10-31T09:00:00',
      ...extra,
    };

    test('đọc tin ảnh', () {
      final parsed = ChatMessage.fromJson(
        message({'type': 'IMAGE', 'imageUrl': 'https://x/a.jpg'}),
      );

      expect(parsed.type, MessageType.image);
      expect(parsed.imageUrl, 'https://x/a.jpg');
      expect(parsed.previewFor(9), '📷 Ảnh');
      expect(parsed.previewFor(3), 'Bạn: 📷 Ảnh');
    });

    test('tin đã thu hồi không lộ nội dung cũ ở Inbox', () {
      final parsed = ChatMessage.fromJson(message({'recalled': true}));

      expect(parsed.recalled, isTrue);
      expect(parsed.previewFor(9), 'Tin nhắn đã thu hồi');
    });

    test('đổi trạng thái vẫn giữ ảnh đang gửi', () {
      final pending = ChatMessage.pendingImage(
        conversationId: 2,
        senderId: 3,
        bytes: Uint8List.fromList([1, 2, 3]),
        clientMsgId: 'c',
      );

      final failed = pending
          .copyWith(imageUrl: 'https://x/a.jpg')
          .copyWith(status: MessageStatus.failed);

      expect(failed.localImage, isNotNull);
      expect(failed.imageUrl, 'https://x/a.jpg');
      expect(failed.status, MessageStatus.failed);
    });

    test('đọc cờ chặn của hội thoại', () {
      final conversation = Conversation.fromJson({
        'id': 1,
        'otherUser': {'id': 2, 'username': 'a'},
        'canMessage': false,
        'blockedByMe': true,
      });

      expect(conversation.canMessage, isFalse);
      expect(conversation.blockedByMe, isTrue);
      expect(conversation.copyWith(unreadCount: 1).blockedByMe, isTrue);
    });

    test('nhận ra chữ Nhật, không nhầm tiếng Việt', () {
      expect(containsJapanese('こんにちは'), isTrue);
      expect(containsJapanese('カタカナ'), isTrue);
      expect(containsJapanese('日本語'), isTrue);
      expect(containsJapanese('Xin chào các bạn'), isFalse);
      expect(containsJapanese(''), isFalse);
    });
  });

  group('trả lời', () {
    test('đọc trích dẫn của tin trả lời', () {
      final message = ChatMessage.fromJson({
        'id': 2,
        'conversationId': 1,
        'senderId': 3,
        'type': 'TEXT',
        'content': 'ok',
        'createdAt': '2026-10-31T09:00:00',
        'replyTo': {
          'id': 1,
          'senderId': 4,
          'type': 'TEXT',
          'content': 'Xin chào',
          'recalled': false,
        },
      });

      expect(message.replyTo!.id, 1);
      expect(message.replyTo!.senderId, 4);
      expect(message.replyTo!.preview, 'Xin chào');
    });

    test('tóm tắt trích dẫn theo loại tin', () {
      MessageReply reply(MessageType type, {bool recalled = false}) =>
          MessageReply(
            id: 1,
            senderId: 2,
            type: type,
            content: '',
            recalled: recalled,
          );

      expect(reply(MessageType.image).preview, '📷 Ảnh');
      expect(reply(MessageType.videoShare).preview, '🎬 Video');
      expect(
        reply(MessageType.text, recalled: true).preview,
        'Tin nhắn đã được thu hồi',
      );
    });
  });
}
