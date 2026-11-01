package com.jlsp.backend.chat.event;

import com.jlsp.backend.chat.dto.response.ReadReceiptResponse;

/**
 * Phát ra khi một người đánh dấu đã đọc; báo cho người kia (hiện "Đã xem") và
 * các thiết bị khác của chính người đó (cập nhật badge).
 */
public record ConversationReadEvent(ReadReceiptResponse receipt, Long otherUserId) {
}
