package com.jlsp.backend.chat.event;

import com.jlsp.backend.chat.dto.response.MessageResponse;

/**
 * Phát ra sau khi lưu tin nhắn; được đẩy realtime tới cả hai người sau khi transaction commit.
 */
public record MessageCreatedEvent(MessageResponse message, Long senderId, Long recipientId) {
}
