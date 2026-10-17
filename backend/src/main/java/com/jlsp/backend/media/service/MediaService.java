package com.jlsp.backend.media.service;

import com.jlsp.backend.media.dto.ImageKitAuthResponse;

/**
 * Interface nghiệp vụ xử lý Media và xác thực tải lên ImageKit.
 */
public interface MediaService {

    /**
     * Sinh các thông số xác thực token, expire, signature để Frontend có thể tải file lên ImageKit.
     *
     * @return ImageKitAuthResponse
     */
    ImageKitAuthResponse getImageKitAuth();
}
