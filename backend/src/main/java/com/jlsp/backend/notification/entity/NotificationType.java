package com.jlsp.backend.notification.entity;

import java.util.Arrays;
import java.util.List;

/**
 * Loại thông báo. Thông báo kiểm duyệt (APPROVED, REJECTED) thuộc nhóm hệ thống và không
 * có người thực hiện. Thông báo báo cáo vi phạm sẽ được thêm vào đây khi luồng report của
 * admin hoàn thành.
 */
public enum NotificationType {
    VIDEO_COMMENTED(NotificationCategory.INTERACTION),
    VIDEO_LIKED(NotificationCategory.INTERACTION),
    VIDEO_SHARED(NotificationCategory.INTERACTION),
    VIDEO_APPROVED(NotificationCategory.SYSTEM),
    VIDEO_REJECTED(NotificationCategory.SYSTEM);

    private final NotificationCategory category;

    NotificationType(NotificationCategory category) {
        this.category = category;
    }

    public NotificationCategory getCategory() {
        return category;
    }

    public static List<NotificationType> ofCategory(NotificationCategory category) {
        return Arrays.stream(values()).filter(type -> type.category == category).toList();
    }
}
