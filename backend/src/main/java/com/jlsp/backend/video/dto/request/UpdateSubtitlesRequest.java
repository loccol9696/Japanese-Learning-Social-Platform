package com.jlsp.backend.video.dto.request;

import jakarta.validation.constraints.NotBlank;
import lombok.*;

/**
 * DTO cập nhật nội dung phụ đề tương tác cho Video.
 * Cấu trúc JSON phụ đề này được thiết kế để đón nhận kết quả từ module AI trích xuất lời thoại tiếng Nhật.
 */
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class UpdateSubtitlesRequest {

    /**
     * Chuỗi JSON chứa danh sách các phân đoạn phụ đề (start_ms, end_ms, text, ruby tokens)
     */
    @NotBlank(message = "Nội dung phụ đề (subtitles) không được để trống")
    private String subtitles;
}
