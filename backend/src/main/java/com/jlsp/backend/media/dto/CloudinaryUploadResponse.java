package com.jlsp.backend.media.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * DTO trả về kết quả sau khi tải file lên Cloudinary thành công.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CloudinaryUploadResponse {
    private String url;
    private String secureUrl;
    private String publicId;
    private String resourceType;
    private String format;
    private Long bytes;
    private Integer width;
    private Integer height;
    private Double duration;
    private String aiTaskId;
    private String aiStatus;
    /** Tiêu đề gốc (khi nhập từ YouTube). */
    private String title;
}
