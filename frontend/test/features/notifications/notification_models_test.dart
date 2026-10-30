import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/notifications/data/models/notification_models.dart';

Map<String, dynamic> _json({
  int id = 1,
  String type = 'VIDEO_LIKED',
  String category = 'INTERACTION',
  bool read = false,
}) => {
  'id': id,
  'type': type,
  'category': category,
  'actorId': 2,
  'actorName': 'Hana',
  'actorAvatarUrl': 'a.png',
  'videoId': 7,
  'videoTitle': 'Chào hỏi',
  'videoThumbnailUrl': 't.png',
  'videoAvailable': true,
  'commentId': 9,
  'detail': 'hay quá',
  'read': read,
  'createdAt': '2026-10-31T09:05:00',
};

void main() {
  group('AppNotification.fromJson', () {
    test('đọc đủ trường', () {
      final n = AppNotification.fromJson(_json());

      expect(n.id, 1);
      expect(n.type, NotificationType.videoLiked);
      expect(n.category, NotificationCategory.interaction);
      expect(n.actorId, 2);
      expect(n.actorName, 'Hana');
      expect(n.videoId, 7);
      expect(n.videoTitle, 'Chào hỏi');
      expect(n.videoAvailable, isTrue);
      expect(n.commentId, 9);
      expect(n.detail, 'hay quá');
      expect(n.isRead, isFalse);
      expect(n.createdAt, DateTime(2026, 10, 31, 9, 5));
      expect(n.isSystem, isFalse);
    });

    test('thông báo hệ thống không có người thực hiện', () {
      final n = AppNotification.fromJson({
        'id': 3,
        'type': 'VIDEO_APPROVED',
        'category': 'SYSTEM',
        'actorId': null,
        'videoId': 7,
        'videoAvailable': true,
        'read': true,
        'createdAt': '2026-10-31T09:05:00',
      });

      expect(n.isSystem, isTrue);
      expect(n.actorId, isNull);
      expect(n.actorName, '');
      expect(n.isRead, isTrue);
    });

    test('copyWith chỉ đổi trạng thái đã đọc', () {
      final n = AppNotification.fromJson(_json());
      final read = n.copyWith(isRead: true);

      expect(read.isRead, isTrue);
      expect(read.id, n.id);
      expect(read.detail, n.detail);
    });
  });

  group('NotificationPage.fromJson', () {
    test('bỏ qua loại thông báo app chưa biết', () {
      final page = NotificationPage.fromJson({
        'content': [_json(id: 1), _json(id: 2, type: 'REPORT_RESOLVED')],
        'last': false,
      });

      expect(page.items.map((n) => n.id), [1]);
      expect(page.isLast, isFalse);
    });

    test('thiếu content thì rỗng và coi là trang cuối', () {
      final page = NotificationPage.fromJson({});

      expect(page.items, isEmpty);
      expect(page.isLast, isTrue);
    });
  });

  group('NotificationTarget.fromPushData', () {
    test('đọc dữ liệu push của thông báo', () {
      final target = NotificationTarget.fromPushData({
        'notificationId': '10',
        'type': 'VIDEO_COMMENTED',
        'videoId': '7',
        'commentId': '9',
      });

      expect(target, isNotNull);
      expect(target!.notificationId, 10);
      expect(target.type, NotificationType.videoCommented);
      expect(target.videoId, 7);
      expect(target.commentId, 9);
    });

    test('push tin nhắn chat không phải thông báo', () {
      expect(
        NotificationTarget.fromPushData({
          'conversationId': '5',
          'messageId': '6',
        }),
        isNull,
      );
    });

    test('loại lạ thì bỏ qua', () {
      expect(
        NotificationTarget.fromPushData({
          'notificationId': '10',
          'type': 'SOMETHING_NEW',
        }),
        isNull,
      );
    });
  });
}
