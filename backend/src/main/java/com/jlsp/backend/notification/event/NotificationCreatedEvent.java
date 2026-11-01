package com.jlsp.backend.notification.event;

import com.jlsp.backend.notification.dto.NotificationResponse;

/** Phát ra sau khi lưu thông báo; được đẩy realtime tới người nhận sau khi transaction commit. */
public record NotificationCreatedEvent(Long recipientId, NotificationResponse notification, long unreadCount) {
}
