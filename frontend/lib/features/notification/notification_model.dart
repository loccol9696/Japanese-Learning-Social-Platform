/// Thông báo trong ứng dụng, khớp `NotificationResponse` của backend.
library;

int? _toInt(dynamic value) =>
    value is num ? value.toInt() : int.tryParse('$value');

enum NotificationType {
  like,
  comment,
  reply,
  follow,
  videoApproved,
  videoRejected,
  reportUpdate,
  contentRemoved,
  unknown;

  static NotificationType parse(String? code) => switch (code) {
    'LIKE' => like,
    'COMMENT' => comment,
    'REPLY' => reply,
    'FOLLOW' => follow,
    'VIDEO_APPROVED' => videoApproved,
    'VIDEO_REJECTED' => videoRejected,
    'REPORT_UPDATE' => reportUpdate,
    'CONTENT_REMOVED' => contentRemoved,
    _ => unknown,
  };
}

class AppNotification {
  final int id;
  final NotificationType type;
  final bool isRead;
  final DateTime? createdAt;
  final int? actorId;
  final String actorUsername;
  final String actorDisplayName;
  final String actorAvatarUrl;
  final int? videoId;
  final String videoTitle;
  final int? commentId;
  final String message;

  const AppNotification({
    required this.id,
    required this.type,
    required this.isRead,
    this.createdAt,
    this.actorId,
    this.actorUsername = '',
    this.actorDisplayName = '',
    this.actorAvatarUrl = '',
    this.videoId,
    this.videoTitle = '',
    this.commentId,
    this.message = '',
  });

  /// Tên hiển thị của người gây ra sự kiện; "Ai đó" với thông báo từ hệ thống.
  String get actorName => actorDisplayName.isNotEmpty
      ? actorDisplayName
      : (actorUsername.isNotEmpty ? actorUsername : 'Ai đó');

  /// Dòng mô tả chính, ví dụ "Sakura đã thích video của bạn".
  String get title {
    final video = videoTitle.isNotEmpty ? ' "$videoTitle"' : '';
    return switch (type) {
      NotificationType.like => '$actorName đã thích video$video của bạn',
      NotificationType.comment => '$actorName đã bình luận về video$video của bạn',
      NotificationType.reply => '$actorName đã trả lời bình luận của bạn',
      NotificationType.follow => '$actorName đã bắt đầu theo dõi bạn',
      NotificationType.videoApproved => 'Video$video của bạn đã được duyệt',
      NotificationType.videoRejected => 'Video$video của bạn bị từ chối',
      NotificationType.reportUpdate => 'Cập nhật về báo cáo của bạn',
      NotificationType.contentRemoved => 'Nội dung của bạn đã bị gỡ',
      NotificationType.unknown => 'Bạn có thông báo mới',
    };
  }

  AppNotification copyWith({bool? isRead}) => AppNotification(
    id: id,
    type: type,
    isRead: isRead ?? this.isRead,
    createdAt: createdAt,
    actorId: actorId,
    actorUsername: actorUsername,
    actorDisplayName: actorDisplayName,
    actorAvatarUrl: actorAvatarUrl,
    videoId: videoId,
    videoTitle: videoTitle,
    commentId: commentId,
    message: message,
  );

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
    id: _toInt(json['id']) ?? 0,
    type: NotificationType.parse(json['type']?.toString()),
    isRead: json['isRead'] == true,
    createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    actorId: _toInt(json['actorId']),
    actorUsername: json['actorUsername']?.toString() ?? '',
    actorDisplayName: json['actorDisplayName']?.toString() ?? '',
    actorAvatarUrl: json['actorAvatarUrl']?.toString() ?? '',
    videoId: _toInt(json['videoId']),
    videoTitle: json['videoTitle']?.toString() ?? '',
    commentId: _toInt(json['commentId']),
    message: json['message']?.toString() ?? '',
  );
}

class NotificationPage {
  final List<AppNotification> items;
  final bool isLast;

  const NotificationPage({required this.items, required this.isLast});
}
