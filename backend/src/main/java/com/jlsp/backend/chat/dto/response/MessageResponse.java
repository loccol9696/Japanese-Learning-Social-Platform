package com.jlsp.backend.chat.dto.response;

import com.jlsp.backend.chat.entity.MessageType;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class MessageResponse {

    private Long id;
    private Long conversationId;
    private Long senderId;
    private MessageType type;
    private String content;
    private SharedVideoResponse video;
    private SharedDeckResponse deck;
    private Integer videoStartMs;
    private String imageUrl;
    private ReplyPreviewResponse replyTo;
    private Boolean recalled;
    private String clientMsgId;
    private LocalDateTime createdAt;
}
