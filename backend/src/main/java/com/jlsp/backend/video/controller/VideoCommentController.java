package com.jlsp.backend.video.controller;

import com.jlsp.backend.common.response.ApiResponse;
import com.jlsp.backend.common.security.CurrentUser;
import com.jlsp.backend.video.dto.request.CommentSort;
import com.jlsp.backend.video.dto.request.CreateCommentRequest;
import com.jlsp.backend.video.dto.response.CommentLikeResponse;
import com.jlsp.backend.video.dto.response.VideoCommentResponse;
import com.jlsp.backend.video.service.CommentService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/videos/{videoId}/comments")
@RequiredArgsConstructor
public class VideoCommentController {
    private final CommentService commentService;

    @GetMapping
    public ResponseEntity<ApiResponse<List<VideoCommentResponse>>> list(
            @PathVariable Long videoId,
            @RequestParam(defaultValue = "HELPFUL") CommentSort sort) {
        return ResponseEntity.ok(ApiResponse.success(commentService.list(videoId, CurrentUser.idOrNull(), sort)));
    }

    @PostMapping("/{commentId}/likes")
    public ResponseEntity<ApiResponse<CommentLikeResponse>> like(
            @PathVariable Long videoId,
            @PathVariable Long commentId) {
        return ResponseEntity.ok(ApiResponse.success(commentService.like(videoId, commentId, CurrentUser.requireId())));
    }

    @DeleteMapping("/{commentId}/likes")
    public ResponseEntity<ApiResponse<CommentLikeResponse>> unlike(
            @PathVariable Long videoId,
            @PathVariable Long commentId) {
        return ResponseEntity.ok(ApiResponse.success(commentService.unlike(videoId, commentId, CurrentUser.requireId())));
    }

    @PostMapping
    public ResponseEntity<ApiResponse<VideoCommentResponse>> create(
            @PathVariable Long videoId,
            @Valid @RequestBody CreateCommentRequest request) {
        VideoCommentResponse response = commentService.create(videoId, CurrentUser.requireId(), request);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.success(HttpStatus.CREATED.value(), "Đã đăng bình luận", response));
    }

    @DeleteMapping("/{commentId}")
    public ResponseEntity<ApiResponse<Void>> delete(
            @PathVariable Long videoId,
            @PathVariable Long commentId) {
        var currentUser = CurrentUser.get()
                .orElseThrow(() -> new org.springframework.security.authentication.AuthenticationCredentialsNotFoundException(
                        "Vui lòng đăng nhập để tiếp tục"));
        commentService.delete(videoId, commentId, currentUser.id(), currentUser.roles().contains("ROLE_ADMIN")
                || currentUser.roles().contains("ADMIN"));
        return ResponseEntity.ok(ApiResponse.success(200, "Đã xóa bình luận", null));
    }
}
