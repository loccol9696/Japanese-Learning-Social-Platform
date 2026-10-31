package com.jlsp.backend.media.controller;

import com.jlsp.backend.common.response.ApiResponse;
import com.jlsp.backend.media.dto.CloudinarySignatureResponse;
import com.jlsp.backend.media.dto.CloudinaryUploadResponse;
import com.jlsp.backend.media.dto.YoutubeImportRequest;
import com.jlsp.backend.media.service.MediaService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

/**
 * REST Controller cung cấp các endpoint cho thao tác Media qua Cloudinary:
 * 1. Sinh chữ ký xác thực cho Frontend tải file trực tiếp.
 * 2. Tải file multipart trực tiếp thông qua Backend.
 */
@RestController
@RequestMapping("/api/v1/media")
@RequiredArgsConstructor
public class MediaController {

    private final MediaService mediaService;

    /**
     * Cung cấp chữ ký Cloudinary (signature, timestamp, apiKey, cloudName)
     * để Frontend (Flutter/Web) tải file trực tiếp lên Cloudinary.
     *
     * GET /api/v1/media/cloudinary-sign?folder=jlsp/videos
     */
    @GetMapping("/cloudinary-sign")
    public ResponseEntity<ApiResponse<CloudinarySignatureResponse>> getCloudinarySignature(
            @RequestParam(value = "folder", required = false, defaultValue = "jlsp") String folder) {
        CloudinarySignatureResponse response = mediaService.getUploadSignature(folder);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    /**
     * Tải file trực tiếp từ Client lên Cloudinary thông qua Backend.
     * Hỗ trợ ảnh, video, âm thanh với kích thước và định dạng tự động nhận diện.
     *
     * POST /api/v1/media/upload
     */
    @PostMapping(value = "/upload", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<ApiResponse<CloudinaryUploadResponse>> uploadMedia(
            @RequestPart("file") MultipartFile file,
            @RequestParam(value = "folder", required = false, defaultValue = "jlsp") String folder) {
        CloudinaryUploadResponse response = mediaService.uploadMedia(file, folder);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    /**
     * Nhập video từ link YouTube: backend tải video (tối đa 10 phút), upload lên Cloudinary
     * và khởi động AI tạo phụ đề. Response giống /upload, kèm "title" gốc của video.
     *
     * POST /api/v1/media/youtube  { "url": "https://www.youtube.com/watch?v=..." }
     */
    @PostMapping("/youtube")
    public ResponseEntity<ApiResponse<CloudinaryUploadResponse>> importFromYoutube(
            @Valid @RequestBody YoutubeImportRequest request) {
        CloudinaryUploadResponse response = mediaService.importFromYoutube(request.getUrl());
        return ResponseEntity.ok(ApiResponse.success(response));
    }
}
