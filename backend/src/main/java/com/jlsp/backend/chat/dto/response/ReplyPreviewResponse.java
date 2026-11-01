package com.jlsp.backend.chat.dto.response;

import com.jlsp.backend.chat.entity.MessageType;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/** Trích dẫn ngắn của tin được trả lời. */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ReplyPreviewResponse {

    private Long id;
    private Long senderId;
    private MessageType type;
    private String content;
    private Boolean recalled;
}
