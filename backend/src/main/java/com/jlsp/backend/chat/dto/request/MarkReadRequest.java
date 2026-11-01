package com.jlsp.backend.chat.dto.request;

import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

/** Đánh dấu đã đọc tới tin nhắn lastMessageId (REST và event "conversation:read"). */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class MarkReadRequest {

    private Long conversationId;

    @NotNull(message = "Thiếu lastMessageId")
    private Long lastMessageId;
}
