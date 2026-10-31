package com.jlsp.backend.video.service;

import com.jlsp.backend.video.dto.request.CommentSort;
import com.jlsp.backend.video.dto.request.CreateCommentRequest;
import com.jlsp.backend.video.dto.response.CommentLikeResponse;
import com.jlsp.backend.video.dto.response.VideoCommentResponse;

import java.util.List;

public interface CommentService {
    /** @param viewerId người đang xem; null thì mọi bình luận có isLiked = false */
    List<VideoCommentResponse> list(Long videoId, Long viewerId, CommentSort sort);
    VideoCommentResponse create(Long videoId, Long userId, CreateCommentRequest request);
    void delete(Long videoId, Long commentId, Long userId, boolean isAdmin);
    CommentLikeResponse like(Long videoId, Long commentId, Long userId);
    CommentLikeResponse unlike(Long videoId, Long commentId, Long userId);
}
