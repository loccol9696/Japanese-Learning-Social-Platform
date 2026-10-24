package com.jlsp.backend.chat.repository;

import com.jlsp.backend.chat.entity.ConversationParticipant;
import com.jlsp.backend.chat.entity.ConversationParticipantId;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

@Repository
public interface ConversationParticipantRepository
        extends JpaRepository<ConversationParticipant, ConversationParticipantId> {

    /**
     * Tổng số tin nhắn chưa đọc của người dùng trên mọi hội thoại (badge Inbox).
     */
    @Query("SELECT COUNT(m) FROM ConversationParticipant p, Message m " +
            "WHERE p.id.userId = :userId AND m.conversation.id = p.id.conversationId " +
            "AND m.sender.id <> :userId AND m.id > COALESCE(p.lastReadMessageId, 0)")
    long countUnreadMessages(@Param("userId") Long userId);
}
