package com.jlsp.backend.chat.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

/**
 * Một trang lịch sử tin nhắn (mới nhất trước). Gọi tiếp với before = nextCursor
 * để lấy tin cũ hơn.
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
