package com.jlsp.backend.chat.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Thẻ bộ từ vựng trong tin nhắn DECK_SHARE. available = false khi bộ thẻ đã bị xoá hoặc chuyển riêng tư —
 * khi đó các trường khác để trống.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class SharedDeckResponse {

    private Long id;
    private Boolean available;
    private String title;
    private Integer cardCount;
}
