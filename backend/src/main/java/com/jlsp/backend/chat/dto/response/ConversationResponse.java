package com.jlsp.backend.chat.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ConversationResponse {

    private Long id;
    private ChatUserResponse otherUser;
    private MessageResponse lastMessage;
    private Long unreadCount;

    /** Người kia đã đọc tới tin nào (hiển thị "Đã xem"). */
    private Long otherLastReadMessageId;

    /** Hai bên còn follow lẫn nhau hay không — false thì chỉ xem lại được lịch sử. */
    private Boolean canMessage;

    private LocalDateTime lastMessageAt;
}
