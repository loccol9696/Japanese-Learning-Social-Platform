package com.jlsp.backend.video.dto.response;

import lombok.Builder;
import lombok.Getter;

import java.time.LocalDateTime;
import java.util.List;

@Getter
@Builder
public class VideoCommentResponse {
    private Long id;
    private Long videoId;
    private Long parentId;
    /** Tên người được trả lời (null với bình luận gốc). */
    private String replyToName;
    /** ID người được trả lời, dùng để mở đúng trang cá nhân. */
    private Long replyToUserId;
    private Long userId;
    private String username;
    private String displayName;
    private String avatarUrl;
    private String content;
    private LocalDateTime createdAt;
    private List<VideoCommentResponse> replies;
}
