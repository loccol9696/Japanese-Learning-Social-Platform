package com.jlsp.backend.media.controller;

import com.jlsp.backend.common.response.ApiResponse;
import com.jlsp.backend.media.dto.ImageKitAuthResponse;
import com.jlsp.backend.media.service.MediaService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * REST Controller cung cấp tham số xác thực cho các thao tác tải lên Media (ImageKit).
 */
@RestController
@RequestMapping("/api/v1/media")
@RequiredArgsConstructor
public class MediaController {

    private final MediaService mediaService;

    /**
     * Cung cấp token, expire và signature để Frontend (Flutter/Web) tải file trực tiếp lên ImageKit.
     * Mặc định trả về chuẩn ApiResponse<ImageKitAuthResponse>.
     * Có thể truyền ?raw=true để trả về JSON thô cho ImageKit Client SDK.
     *
     * GET /api/v1/media/imagekit-auth
     */
    @GetMapping("/imagekit-auth")
    public ResponseEntity<?> getImageKitAuth(
            @RequestParam(value = "raw", defaultValue = "false") boolean raw) {
        ImageKitAuthResponse auth = mediaService.getImageKitAuth();
        if (raw) {
            return ResponseEntity.ok(auth);
        }
        return ResponseEntity.ok(ApiResponse.success(auth));
    }

    /**
     * Endpoint trả về JSON thô không bọc ApiResponse, dùng trực tiếp làm authenticationEndpoint
     * cho ImageKit SDK chính thức trên Flutter hoặc Web.
     *
     * GET /api/v1/media/imagekit-auth/raw
     */
    @GetMapping("/imagekit-auth/raw")
    public ResponseEntity<ImageKitAuthResponse> getImageKitAuthRaw() {
        return ResponseEntity.ok(mediaService.getImageKitAuth());
    }
}
