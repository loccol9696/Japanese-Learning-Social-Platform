package com.jlsp.backend.video.dto.response;

/** Trạng thái ghim của một bình luận sau khi chủ video ghim / bỏ ghim. */
public record CommentFlagsResponse(boolean pinned) {
}
