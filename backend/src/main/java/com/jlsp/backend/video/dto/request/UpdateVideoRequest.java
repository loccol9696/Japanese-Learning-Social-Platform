package com.jlsp.backend.video.dto.request;

import com.jlsp.backend.user.entity.JLPTLevel;
import com.jlsp.backend.video.entity.VideoStatus;
import lombok.*;

/**
 * DTO yêu cầu cập nhật thông tin bài đăng Video (bao gồm cả hoàn thiện bản nháp).
 */
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class UpdateVideoRequest {

    /**
     * Tiêu đề video mới
     */
    private String title;

    /**
     * Mô tả video mới
     */
    private String description;

    /**
     * Đường dẫn ảnh bìa / thumbnail mới
     */
    private String thumbnailUrl;

    /**
     * Cấp độ JLPT mới
     */
    private JLPTLevel jlptLevel;

    /**
     * Chủ đề mới (tối đa 3); null thì giữ nguyên, danh sách rỗng để bỏ hết.
     */
    private java.util.Set<Long> topicIds;

    /**
     * Hashtag mới (tối đa 5); null thì giữ nguyên, danh sách rỗng để bỏ hết.
     */
    private java.util.List<String> hashtags;

    /**
     * Phụ đề JSON mới (tuỳ chọn, khi chỉnh sửa bản nháp hoặc cập nhật toàn bộ).
     */
    private String subtitles;

    /**
     * Kết quả phân tích ngữ pháp JSON (tuỳ chọn, khi chỉnh sửa bản nháp).
     */
    private String grammarAnalysis;

    /**
     * Trạng thái hiển thị mới (PUBLIC, PRIVATE, UNLISTED, DRAFT)
     */
    private VideoStatus status;
}
