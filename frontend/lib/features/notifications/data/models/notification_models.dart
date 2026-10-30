/// Các model của tính năng thông báo, khớp với DTO của backend (module `notification`).
library;

int _toInt(dynamic value, [int fallback = 0]) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? fallback;

int? _toIntOrNull(dynamic value) => value == null
    ? null
    : (value is num ? value.toInt() : int.tryParse('$value'));

/// Nhóm hiển thị: tab Tương tác và tab Hệ thống.
enum NotificationCategory {
  interaction('INTERACTION'),
  system('SYSTEM');

  final String apiValue;

  const NotificationCategory(this.apiValue);

  static NotificationCategory parse(dynamic value) =>
      value?.toString().toUpperCase() == 'SYSTEM'
      ? NotificationCategory.system
      : NotificationCategory.interaction;
}

/// Loại thông báo. Giá trị lạ (server mới hơn app) rơi về [unknown] và bị bỏ qua khi hiển thị.
enum NotificationType {
  videoCommented('VIDEO_COMMENTED'),
  videoLiked('VIDEO_LIKED'),
  videoShared('VIDEO_SHARED'),
  videoApproved('VIDEO_APPROVED'),
  videoRejected('VIDEO_REJECTED'),
  unknown('');

  final String apiValue;

  const NotificationType(this.apiValue);

  static NotificationType parse(dynamic value) {
    final text = value?.toString().toUpperCase();
    return NotificationType.values.firstWhere(
      (type) => type.apiValue.isNotEmpty && type.apiValue == text,
      orElse: () => NotificationType.unknown,
    );
  }
}

class AppNotification {
  final int id;
  final NotificationType type;
  final NotificationCategory category;
  final int? actorId;
  final String actorName;
  final String actorAvatarUrl;
  final int? videoId;
  final String videoTitle;
  final String videoThumbnailUrl;

  /// false khi video đã bị xoá.
  final bool videoAvailable;
  final int? commentId;

  /// Đoạn bình luận (videoCommented) hoặc lý do từ chối (videoRejected).
  final String detail;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.category,
    this.actorId,
    this.actorName = '',
    this.actorAvatarUrl = '',
    this.videoId,
    this.videoTitle = '',
    this.videoThumbnailUrl = '',
    this.videoAvailable = false,
    this.commentId,
    this.detail = '',
    this.isRead = false,
    required this.createdAt,
  });

  bool get isSystem => category == NotificationCategory.system;

  AppNotification copyWith({bool? isRead}) => AppNotification(
    id: id,
    type: type,
    category: category,
    actorId: actorId,
    actorName: actorName,
    actorAvatarUrl: actorAvatarUrl,
    videoId: videoId,
    videoTitle: videoTitle,
    videoThumbnailUrl: videoThumbnailUrl,
    videoAvailable: videoAvailable,
    commentId: commentId,
    detail: detail,
    isRead: isRead ?? this.isRead,
    createdAt: createdAt,
  );

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: _toInt(json['id']),
        type: NotificationType.parse(json['type']),
        category: NotificationCategory.parse(json['category']),
        actorId: _toIntOrNull(json['actorId']),
        actorName: json['actorName']?.toString() ?? '',
        actorAvatarUrl: json['actorAvatarUrl']?.toString() ?? '',
        videoId: _toIntOrNull(json['videoId']),
        videoTitle: json['videoTitle']?.toString() ?? '',
        videoThumbnailUrl: json['videoThumbnailUrl']?.toString() ?? '',
        videoAvailable: json['videoAvailable'] == true,
        commentId: _toIntOrNull(json['commentId']),
        detail: json['detail']?.toString() ?? '',
        isRead: json['read'] == true,
        createdAt:
            DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
            DateTime.now(),
      );
}

class NotificationPage {
  final List<AppNotification> items;
  final bool isLast;

  const NotificationPage({required this.items, required this.isLast});

  factory NotificationPage.fromJson(Map<String, dynamic> json) {
    final content = json['content'];
    return NotificationPage(
      items: content is List
          ? content
                .whereType<Map<String, dynamic>>()
                .map(AppNotification.fromJson)
                .where((n) => n.type != NotificationType.unknown)
                .toList()
          : const [],
      isLast: json['last'] != false,
    );
  }
}

/// Đích cần mở khi người dùng bấm vào thông báo đẩy.
class NotificationTarget {
  final int notificationId;
  final NotificationType type;
  final int? videoId;
  final int? commentId;

  const NotificationTarget({
    required this.notificationId,
    required this.type,
    this.videoId,
    this.commentId,
  });

  /// Null khi dữ liệu push không phải của thông báo (vd. tin nhắn chat).
  static NotificationTarget? fromPushData(Map<String, dynamic> data) {
    final id = _toIntOrNull(data['notificationId']);
    if (id == null) return null;
    final type = NotificationType.parse(data['type']);
    if (type == NotificationType.unknown) return null;
    return NotificationTarget(
      notificationId: id,
      type: type,
      videoId: _toIntOrNull(data['videoId']),
      commentId: _toIntOrNull(data['commentId']),
    );
  }

  factory NotificationTarget.fromNotification(AppNotification n) =>
      NotificationTarget(
        notificationId: n.id,
        type: n.type,
        videoId: n.videoId,
        commentId: n.commentId,
      );
}
