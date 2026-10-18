package com.jlsp.backend.video.dto.request;

import com.jlsp.backend.user.entity.JLPTLevel;
import com.jlsp.backend.video.entity.VideoStatus;
import jakarta.validation.constraints.Size;
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
    @Size(min = 1, max = 255, message = "Tiêu đề video phải từ 1 đến 255 ký tự")
    private String title;

    /**
     * Mô tả video mới
     */
    private String description;

    /**
     * Đường dẫn ảnh bìa / thumbnail mới
     */
    @Size(min = 1, max = 255, message = "Đường dẫn ảnh bìa phải từ 1 đến 255 ký tự")
    private String thumbnailUrl;

    /**
     * Cấp độ JLPT mới
     */
    private JLPTLevel jlptLevel;

    /**
     * Trạng thái hiển thị mới (PUBLIC, PRIVATE, UNLISTED)
     */
    private VideoStatus status;
}
