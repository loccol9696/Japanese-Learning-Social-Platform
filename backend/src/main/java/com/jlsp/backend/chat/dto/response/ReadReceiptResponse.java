package com.jlsp.backend.chat.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/** Payload event "message:read": userId đã đọc tới lastReadMessageId. */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ReadReceiptResponse {

    private Long conversationId;
    private Long userId;
    private Long lastReadMessageId;
}
