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

    /** Không ai chặn ai và cả hai tài khoản còn hoạt động — false thì chỉ xem lại được lịch sử. */
    private Boolean canMessage;

    /** Người đang xem đã chặn người kia (để hiện nút bỏ chặn). */
    private Boolean blockedByMe;

    private LocalDateTime lastMessageAt;
}
