package com.jlsp.backend.chat.entity;

/**
 * Loại tin nhắn:
 * - TEXT: tin nhắn văn bản.
 * - VIDEO_SHARE: chia sẻ một video bài học (kèm lời nhắn và mốc thời gian tuỳ chọn).
 * - DECK_SHARE: chia sẻ một bộ thẻ từ vựng công khai (kèm lời nhắn tuỳ chọn).
 * - IMAGE: ảnh đã tải lên Cloudinary.
 */
public enum MessageType {
    TEXT,
    VIDEO_SHARE,
    IMAGE,
    DECK_SHARE
}
