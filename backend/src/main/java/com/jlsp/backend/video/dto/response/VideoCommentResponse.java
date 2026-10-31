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
    private Long userId;
    private String username;
    private String displayName;
    private String avatarUrl;
    private String content;
    private Integer likeCount;
    private Boolean isLiked;
    private LocalDateTime createdAt;
    private List<VideoCommentResponse> replies;
}
