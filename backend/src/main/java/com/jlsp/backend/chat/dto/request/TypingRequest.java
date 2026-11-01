package com.jlsp.backend.chat.dto.request;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

/** Payload event Socket.IO "typing". */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class TypingRequest {

    private Long conversationId;

    private Boolean isTyping;
}
