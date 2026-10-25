package com.jlsp.backend.chat.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/** Payload event "typing" gửi tới người còn lại trong hội thoại. */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class TypingResponse {

    private Long conversationId;
    private Long userId;
    private Boolean isTyping;
}
