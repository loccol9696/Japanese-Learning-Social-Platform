package com.jlsp.backend.video.event;

/**
 * Phát ra khi video đã bị xóa hẳn, dùng để gỡ file trên cloud sau khi transaction commit.
 * URL là null nếu file đó vẫn đang được video khác dùng.
 */
public record VideoPurgedEvent(String videoUrl, String thumbnailUrl) {
}
