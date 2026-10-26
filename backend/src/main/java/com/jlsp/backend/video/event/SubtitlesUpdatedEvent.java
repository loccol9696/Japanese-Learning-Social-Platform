package com.jlsp.backend.video.event;

/**
 * Phát ra khi subtitles của video được tạo mới / cập nhật,
 * dùng để kích hoạt phân tích ngữ pháp bằng AI sau khi transaction commit.
 */
public record SubtitlesUpdatedEvent(Long videoId) {
}

