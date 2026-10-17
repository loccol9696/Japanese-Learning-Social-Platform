package com.jlsp.backend.video.dto.response;

import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * DTO phản hồi thông tin kết quả bài luyện nói Shadowing.
 */
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ShadowingPracticeResponse {

    /**
     * ID bài luyện tập
     */
    private Long id;

    /**
     * ID người học
     */
    private Long userId;

    /**
     * ID video luyện tập
     */
    private Long videoId;

    /**
     * Tiêu đề video luyện tập
     */
    private String videoTitle;

    /**
     * Đường dẫn file ghi âm của người học
     */
    private String audioUrl;

    /**
     * Điểm số phát âm (0.00 - 100.00) do AI đánh giá (null nếu đang chờ AI)
     */
    private BigDecimal score;

    /**
     * Nhận xét phát âm chi tiết do AI cung cấp (null nếu đang chờ AI)
     */
    private String feedback;

    /**
     * Thời điểm nộp bài
     */
    private LocalDateTime createdAt;
}
