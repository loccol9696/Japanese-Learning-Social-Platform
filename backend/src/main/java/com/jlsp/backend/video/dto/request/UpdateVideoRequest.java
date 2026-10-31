package com.jlsp.backend.video.dto.request;

import com.jlsp.backend.user.entity.JLPTLevel;
import com.jlsp.backend.video.entity.VideoStatus;
import lombok.*;

/**
 * DTO yêu cầu cập nhật thông tin bài đăng Video.
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
     * Chủ đề mới; null thì giữ nguyên, 0 hoặc số âm để bỏ chủ đề.
     */
    private Long topicId;

    /**
     * Trạng thái hiển thị mới (PUBLIC, PRIVATE, UNLISTED)
     */
    private VideoStatus status;
}
