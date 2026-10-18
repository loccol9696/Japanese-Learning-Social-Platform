package com.jlsp.backend.user.controller;

import com.jlsp.backend.common.response.ApiResponse;
import com.jlsp.backend.common.security.CurrentUser;
import com.jlsp.backend.user.dto.request.UpdateUserRequest;
import com.jlsp.backend.common.response.PageResponse;
import com.jlsp.backend.user.dto.response.ProfileStatsResponse;
import com.jlsp.backend.user.dto.response.UserResponse;
import com.jlsp.backend.video.dto.response.VideoResponse;
import com.jlsp.backend.video.service.VideoService;
import com.jlsp.backend.user.service.UserService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

/**
 * Hồ sơ của chính người dùng đang đăng nhập (danh tính lấy từ JWT, không nhận user id từ client).
 */
@RestController
@RequestMapping("/api/v1/profile")
@RequiredArgsConstructor
@Slf4j
public class ProfileController {

    private final UserService userService;
    private final VideoService videoService;

    @GetMapping
    public ResponseEntity<ApiResponse<UserResponse>> getProfile() {
        UserResponse response = userService.getUserById(CurrentUser.requireId());
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    @PutMapping
    public ResponseEntity<ApiResponse<UserResponse>> updateProfile(@Valid @RequestBody UpdateUserRequest request) {
        Long id = CurrentUser.requireId();
        UserResponse response = userService.updateUser(id, request);
        log.info("User {} updated profile via /api/v1/profile", id);
        return ResponseEntity.ok(ApiResponse.success(200, "Cập nhật hồ sơ thành công", response));
    }

    /** Số đang theo dõi / người theo dõi / tổng lượt thích. */
    @GetMapping("/stats")
    public ResponseEntity<ApiResponse<ProfileStatsResponse>> getStats() {
        return ResponseEntity.ok(ApiResponse.success(userService.getProfileStats(CurrentUser.requireId())));
    }

    /** Video đã lưu (bookmark), mới lưu trước. */
    @GetMapping("/saved-videos")
    public ResponseEntity<ApiResponse<PageResponse<VideoResponse>>> getSavedVideos(
            @PageableDefault(size = 30) Pageable pageable) {
        return ResponseEntity.ok(ApiResponse.success(videoService.getSavedVideos(CurrentUser.requireId(), pageable)));
    }

    /** Video đã thích, mới thích trước. */
    @GetMapping("/liked-videos")
    public ResponseEntity<ApiResponse<PageResponse<VideoResponse>>> getLikedVideos(
            @PageableDefault(size = 30) Pageable pageable) {
        return ResponseEntity.ok(ApiResponse.success(videoService.getLikedVideos(CurrentUser.requireId(), pageable)));
    }
}
