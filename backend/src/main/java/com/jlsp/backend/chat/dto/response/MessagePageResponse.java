package com.jlsp.backend.chat.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

/**
 * Một trang tin nhắn. Truy vấn thường (before) trả mới nhất trước, gọi tiếp với
 * before = nextCursor để lấy tin cũ hơn. Truy vấn after trả cũ nhất trước, gọi tiếp
 * với after = nextCursor để lấy tin mới hơn.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class MessagePageResponse {

    private List<MessageResponse> content;
    private Boolean hasMore;
    private Long nextCursor;
}
