package com.jlsp.backend.media.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * DTO chứa các thông số xác thực tải lên trực tiếp (Client-side upload) của ImageKit.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ImageKitAuthResponse {

    /**
     * Mã token ngẫu nhiên (UUID) được sinh từ server cho phiên tải lên.
     */
    private String token;

    /**
     * Thời gian hết hạn của phiên tải lên (Epoch timestamp tính bằng giây).
     */
    private long expire;

    /**
     * Chữ ký bảo mật HMAC-SHA1 được sinh từ (token + expire) và ImageKit private key.
     */
    private String signature;
}
