package com.jlsp.backend.chat.event;

/**
 * Phát ra khi một người xoá đoạn chat, để các thiết bị khác của chính người đó cập nhật.
 */
public record ConversationClearedEvent(Long conversationId, Long userId) {
}
