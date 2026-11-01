package com.jlsp.backend.video.dto.request;

import lombok.Getter;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Sort;

/**
 * Thứ tự bình luận gốc của video. HELPFUL được xếp lại trong bộ nhớ bằng
 * {@link com.jlsp.backend.video.service.CommentRanker}; thứ tự ở đây chỉ là thứ tự đọc từ DB.
 */
@Getter
@RequiredArgsConstructor
public enum CommentSort {
    HELPFUL(Sort.by(Sort.Order.desc("likeCount"), Sort.Order.desc("createdAt"), Sort.Order.desc("id"))),
    NEWEST(Sort.by(Sort.Order.desc("createdAt"), Sort.Order.desc("id")));

    private final Sort order;
}
