package com.jlsp.backend.chat.event;

import com.jlsp.backend.chat.dto.response.MessageResponse;

/**
 * Phát sau khi một tin được thu hồi để gửi bản đã xoá nội dung tới hai bên.
 */
public record MessageRecalledEvent(MessageResponse message, Long senderId, Long recipientId) {
}
