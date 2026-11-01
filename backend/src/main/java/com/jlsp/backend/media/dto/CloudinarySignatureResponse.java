package com.jlsp.backend.media.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * DTO chứa thông số xác thực chữ ký (Signature) để Frontend (Flutter/Web) tải file trực tiếp lên Cloudinary.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CloudinarySignatureResponse {
    private String signature;
    private long timestamp;
    private String apiKey;
    private String cloudName;
    private String folder;
}
