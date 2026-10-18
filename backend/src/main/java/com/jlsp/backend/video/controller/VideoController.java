package com.jlsp.backend.video.controller;

import com.jlsp.backend.common.response.ApiResponse;
import com.jlsp.backend.common.response.PageResponse;
import com.jlsp.backend.common.security.CurrentUser;
import com.jlsp.backend.user.entity.JLPTLevel;
import com.jlsp.backend.video.dto.request.CreateVideoRequest;
import com.jlsp.backend.video.dto.request.ShadowingSubmissionRequest;
import com.jlsp.backend.video.dto.request.UpdateSubtitlesRequest;
import com.jlsp.backend.video.dto.request.UpdateVideoRequest;
import com.jlsp.backend.video.dto.response.ShadowingPracticeResponse;
import com.jlsp.backend.video.dto.response.VideoDetailResponse;
import com.jlsp.backend.video.dto.response.VideoResponse;
import com.jlsp.backend.video.service.VideoService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/videos")
@RequiredArgsConstructor
public class VideoController {

    private final VideoService videoService;

    /**
     * Hỗ trợ lọc theo loại feed ("for-you", "following"), cấp độ JLPT, hoặc Creator
     * ID qua Query Parameters.
     * GET /api/v1/videos
     */
    @GetMapping
    public ResponseEntity<ApiResponse<PageResponse<VideoResponse>>> getAllVideos(
            @RequestParam(value = "feed", required = false, defaultValue = "for-you") String feed,
            @RequestParam(value = "jlptLevel", required = false) JLPTLevel jlptLevel,
            @RequestParam(value = "userId", required = false) Long targetUserId,
            @PageableDefault(size = 10, sort = "createdAt", direction = Sort.Direction.DESC) Pageable pageable) {

        Long currentUserId = CurrentUser.idOrNull();
        PageResponse<VideoResponse> response = videoService.getAllVideos(currentUserId, feed, jlptLevel, targetUserId,
                pageable);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    /**
     * POST /api/v1/videos
     */
    @PostMapping
    public ResponseEntity<ApiResponse<VideoDetailResponse>> createVideo(
            @Valid @RequestBody CreateVideoRequest request) {

        Long userId = CurrentUser.requireId();

        VideoDetailResponse response = videoService.createVideo(userId, request);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.success(HttpStatus.CREATED.value(), "Video đã được tạo thành công", response));
    }

    /**
     * Lấy chi tiết một video bài học (bao gồm mô tả và phụ đề tương tác JSON).
     * GET /api/v1/videos/{id}
     */
    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<VideoDetailResponse>> getVideoById(
            @PathVariable Long id) {

        Long userId = CurrentUser.idOrNull();
        VideoDetailResponse response = videoService.getVideoById(id, userId);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    /**
     * Chỉnh sửa toàn bộ thông tin bài học video (Chỉ chủ video hoặc ADMIN mới có
     * quyền).
     * PUT /api/v1/videos/{id}
     */
    @PutMapping("/{id}")
    public ResponseEntity<ApiResponse<VideoDetailResponse>> updateVideo(
            @PathVariable Long id,
            @Valid @RequestBody UpdateVideoRequest request) {

        Long userId = CurrentUser.requireId();

        VideoDetailResponse response = videoService.updateVideo(id, userId, request);
        return ResponseEntity.ok(ApiResponse.success(200, "Cập nhật video thành công", response));
    }

    /**
     * PATCH /api/v1/videos/{id}
     */
    @PatchMapping("/{id}")
    public ResponseEntity<ApiResponse<VideoDetailResponse>> patchVideo(
            @PathVariable Long id,
            @Valid @RequestBody UpdateVideoRequest request) {

        Long userId = CurrentUser.requireId();

        VideoDetailResponse response = videoService.updateVideo(id, userId, request);
        return ResponseEntity.ok(ApiResponse.success(200, "Cập nhật thông tin video thành công", response));
    }

    /**
     * Xóa video khỏi hệ thống (Chỉ chủ video hoặc ADMIN mới có quyền).
     * DELETE /api/v1/videos/{id}
     */
    @DeleteMapping("/{id}")
    public ResponseEntity<ApiResponse<Void>> deleteVideo(
            @PathVariable Long id) {

        Long userId = CurrentUser.requireId();

        videoService.deleteVideo(id, userId);
        return ResponseEntity.ok(ApiResponse.success(200, "Xóa video thành công", null));
    }

    /*
     * POST /api/v1/videos/{id}/likes
     */
    @PostMapping("/{id}/likes")
    public ResponseEntity<ApiResponse<Void>> likeVideo(
            @PathVariable Long id) {

        Long userId = CurrentUser.requireId();

        videoService.likeVideo(id, userId);
        return ResponseEntity.ok(ApiResponse.success(200, "Đã thích video", null));
    }

    /**
     * DELETE /api/v1/videos/{id}/likes
     */
    @DeleteMapping("/{id}/likes")
    public ResponseEntity<ApiResponse<Void>> unlikeVideo(
            @PathVariable Long id) {

        Long userId = CurrentUser.requireId();

        videoService.unlikeVideo(id, userId);
        return ResponseEntity.ok(ApiResponse.success(200, "Đã hủy thích video", null));
    }

    /**
     * Endpoint toggle Like (Hỗ trợ tương thích ngược cho client cũ).
     * POST /api/v1/videos/{id}/like
     */
    @PostMapping("/{id}/like")
    public ResponseEntity<ApiResponse<Boolean>> toggleLike(
            @PathVariable Long id) {

        Long userId = CurrentUser.requireId();

        boolean isLiked = videoService.toggleLike(id, userId);
        String message = isLiked ? "Đã thích video" : "Đã hủy thích video";
        return ResponseEntity.ok(ApiResponse.success(200, message, isLiked));
    }

    /**
     * Lưu video vào bộ sưu tập cá nhân (Save)
     * POST /api/v1/videos/{id}/saves
     */
    @PostMapping("/{id}/saves")
    public ResponseEntity<ApiResponse<Void>> saveVideo(
            @PathVariable Long id) {

        Long userId = CurrentUser.requireId();

        videoService.saveVideo(id, userId);
        return ResponseEntity.ok(ApiResponse.success(200, "Đã lưu video vào bộ sưu tập", null));
    }

    /**
     * Bỏ lưu video khỏi bộ sưu tập (Unsave)
     * DELETE /api/v1/videos/{id}/saves
     */
    @DeleteMapping("/{id}/saves")
    public ResponseEntity<ApiResponse<Void>> unsaveVideo(
            @PathVariable Long id) {

        Long userId = CurrentUser.requireId();

        videoService.unsaveVideo(id, userId);
        return ResponseEntity.ok(ApiResponse.success(200, "Đã bỏ lưu video", null));
    }

    /**
     * Endpoint toggle Save (Hỗ trợ tương thích ngược cho client cũ).
     * POST /api/v1/videos/{id}/save
     */
    @PostMapping("/{id}/save")
    public ResponseEntity<ApiResponse<Boolean>> toggleSave(
            @PathVariable Long id) {

        Long userId = CurrentUser.requireId();

        boolean isSaved = videoService.toggleSave(id, userId);
        String message = isSaved ? "Đã lưu video vào bộ sưu tập" : "Đã bỏ lưu video";
        return ResponseEntity.ok(ApiResponse.success(200, message, isSaved));
    }

    /**
     * Ghi nhận lượt xem hợp lệ cho video
     * POST /api/v1/videos/{id}/views
     */
    @PostMapping("/{id}/views")
    public ResponseEntity<ApiResponse<Void>> incrementViewCount(@PathVariable Long id) {
        videoService.incrementViewCount(id);
        return ResponseEntity.ok(ApiResponse.success(200, "Đã ghi nhận lượt xem", null));
    }

    /**
     * Lấy dữ liệu phụ đề tương tác JSON của video.
     * GET /api/v1/videos/{id}/subtitles
     */
    @GetMapping("/{id}/subtitles")
    public ResponseEntity<ApiResponse<String>> getSubtitles(@PathVariable Long id) {
        String subtitles = videoService.getSubtitles(id);
        return ResponseEntity.ok(ApiResponse.success(subtitles));
    }

    /**
     * Cập nhật dữ liệu phụ đề tương tác JSON (chứa phân đoạn start/end, text,
     * ruby/furigana).
     * PUT /api/v1/videos/{id}/subtitles
     */
    @PutMapping("/{id}/subtitles")
    public ResponseEntity<ApiResponse<VideoDetailResponse>> updateSubtitles(
            @PathVariable Long id,
            @Valid @RequestBody UpdateSubtitlesRequest request) {

        Long userId = CurrentUser.requireId();

        VideoDetailResponse response = videoService.updateSubtitles(id, userId, request.getSubtitles());
        return ResponseEntity.ok(ApiResponse.success(200, "Cập nhật phụ đề thành công", response));
    }

    /**
     * Nộp bài luyện nói Shadowing
     * POST /api/v1/videos/{id}/shadowing-practices
     */
    @PostMapping("/{id}/shadowing-practices")
    public ResponseEntity<ApiResponse<ShadowingPracticeResponse>> submitShadowingPractice(
            @PathVariable Long id,
            @Valid @RequestBody ShadowingSubmissionRequest request) {

        Long userId = CurrentUser.requireId();

        ShadowingPracticeResponse response = videoService.submitShadowing(id, userId, request);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.success(HttpStatus.CREATED.value(),
                        "Nộp bài luyện nói thành công, đang chờ AI chấm điểm", response));
    }

    /**
     * Lấy danh sách các bài luyện nói Shadowing của người dùng cho video này.
     * GET /api/v1/videos/{id}/shadowing-practices
     */
    @GetMapping("/{id}/shadowing-practices")
    public ResponseEntity<ApiResponse<List<ShadowingPracticeResponse>>> getShadowingPractices(
            @PathVariable Long id) {

        Long userId = CurrentUser.requireId();

        List<ShadowingPracticeResponse> response = videoService.getShadowingHistory(id, userId);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    /**
     * Alias nộp bài luyện nói
     * POST /api/v1/videos/{id}/shadowing
     */
    @PostMapping("/{id}/shadowing")
    public ResponseEntity<ApiResponse<ShadowingPracticeResponse>> submitShadowingLegacy(
            @PathVariable Long id,
            @Valid @RequestBody ShadowingSubmissionRequest request) {
        return submitShadowingPractice(id, request);
    }

    /**
     * Alias lấy lịch sử luyện nói (Hỗ trợ tương thích ngược cho client cũ).
     * GET /api/v1/videos/{id}/shadowing/history
     */
    @GetMapping("/{id}/shadowing/history")
    public ResponseEntity<ApiResponse<List<ShadowingPracticeResponse>>> getShadowingHistoryLegacy(
            @PathVariable Long id) {
        return getShadowingPractices(id);
    }

    /**
     * Alias Feed Dành cho bạn
     * GET /api/v1/videos/feed/for-you
     */
    @GetMapping("/feed/for-you")
    public ResponseEntity<ApiResponse<PageResponse<VideoResponse>>> getForYouFeed(
            @RequestParam(value = "jlptLevel", required = false) JLPTLevel jlptLevel,
            @PageableDefault(size = 10, sort = "createdAt", direction = Sort.Direction.DESC) Pageable pageable) {

        Long userId = CurrentUser.idOrNull();
        PageResponse<VideoResponse> response = videoService.getForYouFeed(userId, jlptLevel, pageable);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    /**
     * Alias Following Feed
     * GET /api/v1/videos/feed/following
     */
    @GetMapping("/feed/following")
    public ResponseEntity<ApiResponse<PageResponse<VideoResponse>>> getFollowingFeed(
            @PageableDefault(size = 10, sort = "createdAt", direction = Sort.Direction.DESC) Pageable pageable) {

        Long userId = CurrentUser.requireId();

        PageResponse<VideoResponse> response = videoService.getFollowingFeed(userId, pageable);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    /**
     * Alias danh sách video của Creator
     * GET /api/v1/videos/user/{userId}
     */
    @GetMapping("/user/{userId}")
    public ResponseEntity<ApiResponse<PageResponse<VideoResponse>>> getVideosByUserId(
            @PathVariable Long userId,
            @PageableDefault(size = 10, sort = "createdAt", direction = Sort.Direction.DESC) Pageable pageable) {

        Long viewerId = CurrentUser.idOrNull();
        PageResponse<VideoResponse> response = videoService.getVideosByUserId(userId, viewerId, pageable);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    /**
     * Lấy danh sách video chờ duyệt hoặc theo trạng thái dành cho Admin / Moderator.
     * GET /api/v1/videos/moderation
     */
    @GetMapping("/moderation")
    public ResponseEntity<ApiResponse<PageResponse<VideoResponse>>> getModerationVideos(
            @RequestParam(value = "status", required = false) com.jlsp.backend.video.entity.VideoModStatus status,
            @RequestParam(value = "modStatus", required = false) com.jlsp.backend.video.entity.VideoModStatus modStatus,
            @PageableDefault(size = 20, sort = "createdAt", direction = Sort.Direction.DESC) Pageable pageable) {

        com.jlsp.backend.video.entity.VideoModStatus targetStatus = status != null ? status : (modStatus != null ? modStatus : com.jlsp.backend.video.entity.VideoModStatus.PENDING);
        PageResponse<VideoResponse> response = videoService.getModerationVideos(targetStatus, pageable);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    /**
     * Admin / Moderator duyệt video công khai lên feed.
     * POST /api/v1/videos/{id}/approve
     */
    @PostMapping("/{id}/approve")
    public ResponseEntity<ApiResponse<VideoDetailResponse>> approveVideo(
            @PathVariable Long id) {

        Long moderatorId = CurrentUser.requireId();

        VideoDetailResponse response = videoService.approveVideo(id, moderatorId);
        return ResponseEntity.ok(ApiResponse.success(200, "Đã phê duyệt video thành công", response));
    }

    /**
     * Admin / Moderator từ chối video kèm lý do vi phạm.
     * POST /api/v1/videos/{id}/reject
     */
    @PostMapping("/{id}/reject")
    public ResponseEntity<ApiResponse<VideoDetailResponse>> rejectVideo(
            @PathVariable Long id,
            @Valid @RequestBody com.jlsp.backend.video.dto.request.RejectVideoRequest request) {

        Long moderatorId = CurrentUser.requireId();

        VideoDetailResponse response = videoService.rejectVideo(id, moderatorId, request.getReason());
        return ResponseEntity.ok(ApiResponse.success(200, "Đã từ chối video do vi phạm", response));
    }

    /**
     * Creator kiểm tra trạng thái các video mình đã đăng (kèm lý do nếu bị từ chối).
     * GET /api/v1/videos/my-status
     */
    @GetMapping("/my-status")
    public ResponseEntity<ApiResponse<PageResponse<VideoResponse>>> getMyVideosStatus(
            @PageableDefault(size = 20, sort = "createdAt", direction = Sort.Direction.DESC) Pageable pageable) {

        Long userId = CurrentUser.requireId();

        PageResponse<VideoResponse> response = videoService.getMyVideosStatus(userId, pageable);
        return ResponseEntity.ok(ApiResponse.success(response));
    }
}
