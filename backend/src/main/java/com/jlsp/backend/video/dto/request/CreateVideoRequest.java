package com.jlsp.backend.video.dto.request;

import com.jlsp.backend.user.entity.JLPTLevel;
import com.jlsp.backend.video.entity.VideoStatus;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.*;

/**
 * DTO yêu cầu tạo mới một bài đăng Video học tiếng Nhật.
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class CreateVideoRequest {

    /**
     * Tiêu đề của video (bắt buộc)
     */
    @NotBlank(message = "Tiêu đề video không được để trống")
    private String title;

    /**
     * Mô tả chi tiết nội dung video (tùy chọn)
     */
    private String description;

    /**
     * Đường dẫn ảnh bìa / thumbnail của video (bắt buộc)
     */
    @NotBlank(message = "Ảnh bìa video (thumbnailUrl) không được để trống")
    private String thumbnailUrl;

    /**
     * Thời lượng video tính bằng giây (tối thiểu 1 giây)
     */
    @NotNull(message = "Thời lượng video (duration) không được để trống")
    @Min(value = 1, message = "Thời lượng video tối thiểu là 1 giây")
    private Integer duration;

    /**
     * Cấp độ JLPT tương ứng (N5 -> N1)
     */
    @NotNull(message = "Cấp độ JLPT không được để trống")
    private JLPTLevel jlptLevel;

    /**
     * Đường dẫn file video (MP4 hoặc HLS .m3u8)
     */
    @NotBlank(message = "Đường dẫn video (videoUrl) không được để trống")
    private String videoUrl;

    /**
     * Dữ liệu phụ đề tương tác định dạng JSON (nếu đã có sẵn hoặc do AI nạp vào)
     */
    private String subtitles;

    /**
     * Dữ liệu phân tích ngữ pháp định dạng JSON (nếu có)
     */
    private String grammarAnalysis;

    /**
     * Trạng thái hiển thị (Mặc định là PUBLIC nếu null)
     */
    private VideoStatus status;
}
