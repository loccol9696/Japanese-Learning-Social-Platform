package com.jlsp.backend.notification.event;

import com.jlsp.backend.notification.entity.NotificationType;

/**
 * Nghiệp vụ (like, bình luận, chia sẻ, kiểm duyệt) phát sự kiện này để yêu cầu tạo thông báo.
 * Thông báo được lưu sau khi transaction của nghiệp vụ commit, nên lỗi thông báo không bao giờ
 * làm hỏng thao tác gốc.
 *
 * @param actorId   người thực hiện; null với thông báo hệ thống
 * @param dedupeKey khoá chống trùng; null nếu mỗi lần xảy ra đều báo
 */
public record NotificationRequestedEvent(
        Long recipientId,
        Long actorId,
        NotificationType type,
        Long videoId,
        Long commentId,
        String detail,
        String dedupeKey) {

    public static NotificationRequestedEvent liked(Long ownerId, Long actorId, Long videoId) {
        return new NotificationRequestedEvent(ownerId, actorId, NotificationType.VIDEO_LIKED, videoId, null, null,
                "like:" + actorId + ":" + videoId);
    }

    public static NotificationRequestedEvent shared(Long ownerId, Long actorId, Long videoId) {
        return new NotificationRequestedEvent(ownerId, actorId, NotificationType.VIDEO_SHARED, videoId, null, null,
                "share:" + actorId + ":" + videoId);
    }

    public static NotificationRequestedEvent commented(Long ownerId, Long actorId, Long videoId, Long commentId,
                                                        String content) {
        return new NotificationRequestedEvent(ownerId, actorId, NotificationType.VIDEO_COMMENTED, videoId,
                commentId, content, null);
    }

    public static NotificationRequestedEvent approved(Long ownerId, Long videoId) {
        return new NotificationRequestedEvent(ownerId, null, NotificationType.VIDEO_APPROVED, videoId, null, null,
                null);
    }

    public static NotificationRequestedEvent rejected(Long ownerId, Long videoId, String reason) {
        return new NotificationRequestedEvent(ownerId, null, NotificationType.VIDEO_REJECTED, videoId, null, reason,
                null);
    }
}
