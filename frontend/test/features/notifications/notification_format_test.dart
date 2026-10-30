import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/notifications/data/models/notification_models.dart';
import 'package:frontend/features/notifications/presentation/notification_format.dart';

AppNotification _notification(
  NotificationType type, {
  String actorName = 'Hana',
  String videoTitle = 'Chào hỏi',
  String detail = '',
}) => AppNotification(
  id: 1,
  type: type,
  category:
      type == NotificationType.videoApproved ||
          type == NotificationType.videoRejected
      ? NotificationCategory.system
      : NotificationCategory.interaction,
  actorName: actorName,
  videoTitle: videoTitle,
  detail: detail,
  createdAt: DateTime(2026, 10, 31, 9),
);

void main() {
  group('notificationSentence (tiếng Việt mặc định)', () {
    test('thông báo tương tác nêu tên người thực hiện', () {
      expect(
        notificationSentence(_notification(NotificationType.videoLiked)),
        'Hana đã thích video của bạn',
      );
      expect(
        notificationSentence(_notification(NotificationType.videoCommented)),
        'Hana đã bình luận về video của bạn',
      );
      expect(
        notificationSentence(_notification(NotificationType.videoShared)),
        'Hana đã chia sẻ video của bạn',
      );
    });

    test('thiếu tên thì dùng "Một người dùng"', () {
      expect(
        notificationSentence(
          _notification(NotificationType.videoLiked, actorName: ''),
        ),
        'Một người dùng đã thích video của bạn',
      );
    });

    test('thông báo hệ thống nêu tên video và không có tên người duyệt', () {
      expect(
        notificationSentence(_notification(NotificationType.videoApproved)),
        'Video “Chào hỏi” đã được duyệt và đăng công khai',
      );
      expect(
        notificationSentence(_notification(NotificationType.videoRejected)),
        'Video “Chào hỏi” đã bị từ chối',
      );
    });
  });

  group('notificationDetail', () {
    test('bình luận hiện nguyên văn', () {
      expect(
        notificationDetail(
          _notification(NotificationType.videoCommented, detail: 'hay quá'),
        ),
        'hay quá',
      );
    });

    test('lý do từ chối có tiền tố', () {
      expect(
        notificationDetail(
          _notification(NotificationType.videoRejected, detail: 'Vi phạm'),
        ),
        'Lý do: Vi phạm',
      );
    });

    test('không có chi tiết thì rỗng', () {
      expect(
        notificationDetail(_notification(NotificationType.videoLiked)),
        '',
      );
    });
  });

  group('formatNotificationTime', () {
    final now = DateTime(2026, 10, 31, 12);

    test('mốc tương đối', () {
      expect(
        formatNotificationTime(now.subtract(const Duration(seconds: 20)), now: now),
        'Vừa xong',
      );
      expect(
        formatNotificationTime(now.subtract(const Duration(minutes: 5)), now: now),
        '5 phút trước',
      );
      expect(
        formatNotificationTime(now.subtract(const Duration(hours: 3)), now: now),
        '3 giờ trước',
      );
      expect(
        formatNotificationTime(now.subtract(const Duration(days: 2)), now: now),
        '2 ngày trước',
      );
    });

    test('quá một tuần thì hiện ngày, khác năm thì kèm năm', () {
      expect(formatNotificationTime(DateTime(2026, 10, 1), now: now), '01/10');
      expect(
        formatNotificationTime(DateTime(2025, 12, 25), now: now),
        '25/12/2025',
      );
    });

    test('giờ lệch về tương lai vẫn là "Vừa xong"', () {
      expect(
        formatNotificationTime(now.add(const Duration(minutes: 3)), now: now),
        'Vừa xong',
      );
    });
  });
}
