package com.jlsp.backend.video.dto.response;

import lombok.AllArgsConstructor;
import lombok.Getter;

/** Trạng thái đánh giá sau khi người dùng nhấn "hữu ích". */
@Getter
@AllArgsConstructor
public class CommentLikeResponse {
    private Boolean isLiked;
    private Integer likeCount;
}
