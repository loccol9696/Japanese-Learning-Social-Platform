package com.jlsp.backend.video.dto.request;

import lombok.Getter;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Sort;

/**
 * Thứ tự bình luận gốc của video. Khi chưa có lượt đánh giá nào, HELPFUL trùng với NEWEST.
 */
@Getter
@RequiredArgsConstructor
public enum CommentSort {
    HELPFUL(Sort.by(Sort.Order.desc("likeCount"), Sort.Order.desc("createdAt"), Sort.Order.desc("id"))),
    NEWEST(Sort.by(Sort.Order.desc("createdAt"), Sort.Order.desc("id")));

    private final Sort order;
}
