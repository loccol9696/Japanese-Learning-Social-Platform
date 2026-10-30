package com.jlsp.backend.notification.event;

import com.jlsp.backend.notification.dto.response.NotificationResponse;

/** Phát ra sau khi lưu thông báo; được đẩy realtime và gửi thông báo đẩy sau khi commit. */
public record NotificationCreatedEvent(NotificationResponse notification, Long recipientId) {
}
