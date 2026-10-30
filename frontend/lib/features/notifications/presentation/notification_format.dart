/// Văn bản hiển thị của thông báo. Câu được dựng ở client theo loại thông báo để theo
/// ngôn ngữ đang chọn của app.
library;

import '../../../core/localization/locale_manager.dart';
import '../data/models/notification_models.dart';

String _two(int value) => value.toString().padLeft(2, '0');

/// Tên người thực hiện; thông báo hệ thống không có.
String notificationActorName(AppNotification n) =>
    n.actorName.isEmpty ? appStrings.notificationSomeone : n.actorName;

/// Câu chính của thông báo, vd. "Hana đã thích video của bạn".
String notificationSentence(AppNotification n) {
  final strings = appStrings;
  final title = n.videoTitle.isEmpty ? '—' : n.videoTitle;
  return switch (n.type) {
    NotificationType.videoCommented => strings.notificationCommented(
      notificationActorName(n),
    ),
    NotificationType.videoLiked => strings.notificationLiked(
      notificationActorName(n),
    ),
    NotificationType.videoShared => strings.notificationShared(
      notificationActorName(n),
    ),
    NotificationType.videoApproved => strings.notificationApproved(title),
    NotificationType.videoRejected => strings.notificationRejected(title),
    NotificationType.unknown => '',
  };
}

/// Dòng phụ: nội dung bình luận hoặc lý do từ chối; rỗng nếu không có.
String notificationDetail(AppNotification n) {
  if (n.detail.isEmpty) return '';
  return n.type == NotificationType.videoRejected
      ? appStrings.notificationReason(n.detail)
      : n.detail;
}

/// Thời gian tương đối: "Vừa xong", "5 phút trước", ... quá một tuần thì hiện ngày.
String formatNotificationTime(DateTime time, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final diff = current.difference(time);
  final strings = appStrings;
  if (diff.inMinutes < 1) return strings.timeJustNow;
  if (diff.inMinutes < 60) return strings.timeMinutesAgo(diff.inMinutes);
  if (diff.inHours < 24) return strings.timeHoursAgo(diff.inHours);
  if (diff.inDays < 7) return strings.timeDaysAgo(diff.inDays);
  final date = '${_two(time.day)}/${_two(time.month)}';
  return time.year == current.year ? date : '$date/${time.year}';
}
