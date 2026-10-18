package com.jlsp.backend.video.dto.request;

import jakarta.validation.constraints.NotBlank;
import lombok.*;

/**
 * DTO học viên nộp bài luyện nói nhại theo (Shadowing) cho video bài học.
 */
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ShadowingSubmissionRequest {

    /**
     * Đường dẫn file ghi âm giọng nói của học viên (URL upload từ client)
     */
    @NotBlank(message = "Đường dẫn file ghi âm (audioUrl) không được để trống")
    private String audioUrl;
}
