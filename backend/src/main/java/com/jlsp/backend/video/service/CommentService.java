package com.jlsp.backend.video.service;

import com.jlsp.backend.video.dto.request.CreateCommentRequest;
import com.jlsp.backend.video.dto.response.VideoCommentResponse;

import java.util.List;

public interface CommentService {
    List<VideoCommentResponse> list(Long videoId);
    VideoCommentResponse create(Long videoId, Long userId, CreateCommentRequest request);
    void delete(Long videoId, Long commentId, Long userId, boolean isAdmin);
}
