package com.jlsp.backend.notification.entity;

public enum NotificationType {
    LIKE,
    COMMENT,
    REPLY,
    /** Có người đánh giá "hữu ích" bình luận của bạn. */
    COMMENT_LIKED,
    /** Có người lưu video của bạn vào bộ sưu tập. */
    VIDEO_SAVED,
    /** Có người chia sẻ video của bạn cho bạn bè qua chat. */
    VIDEO_SHARED,
    FOLLOW,
    VIDEO_APPROVED,
    VIDEO_REJECTED,
    REPORT_UPDATE,
    CONTENT_REMOVED
}
