package com.jlsp.backend.chat.entity;

import com.jlsp.backend.user.entity.User;
import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

/**
 * Trạng thái riêng của từng người trong một hội thoại (đã đọc tới đâu).
 */
@Entity
@Table(name = "conversation_participants")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ConversationParticipant {

    @EmbeddedId
    private ConversationParticipantId id;

    @ManyToOne(fetch = FetchType.LAZY)
    @MapsId("conversationId")
    @JoinColumn(name = "conversation_id", nullable = false)
    private Conversation conversation;

    @ManyToOne(fetch = FetchType.LAZY)
    @MapsId("userId")
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    /**
     * ID tin nhắn cuối cùng người này đã đọc (null = chưa đọc tin nào).
     * Tin nhắn của người kia có id lớn hơn giá trị này được tính là chưa đọc.
     */
    @Column(name = "last_read_message_id")
    private Long lastReadMessageId;

    /**
     * Người này đã "xoá cuộc trò chuyện" (chỉ phía họ): các tin có id nhỏ hơn hoặc bằng giá trị này bị ẩn khỏi
     * lịch sử và hội thoại biến mất khỏi hộp thư cho tới khi có tin mới hơn. Người kia không bị ảnh hưởng.
     */
    @Column(name = "cleared_before_message_id")
    private Long clearedBeforeMessageId;

    @Column(name = "joined_at", nullable = false, updatable = false)
    private LocalDateTime joinedAt;

    @PrePersist
    protected void onCreate() {
        this.joinedAt = LocalDateTime.now();
    }
}
