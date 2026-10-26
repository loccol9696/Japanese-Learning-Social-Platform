package com.jlsp.backend.video.service;

import com.jlsp.backend.video.dto.request.CreateCommentRequest;
import com.jlsp.backend.video.dto.response.VideoCommentResponse;

import java.util.List;

public interface CommentService {
    /** @param viewerId người xem (null nếu khách); bình luận của người có quan hệ chặn với họ bị ẩn */
    List<VideoCommentResponse> list(Long videoId, Long viewerId);
    VideoCommentResponse create(Long videoId, Long userId, CreateCommentRequest request);
    void delete(Long videoId, Long commentId, Long userId, boolean isAdmin);
}
