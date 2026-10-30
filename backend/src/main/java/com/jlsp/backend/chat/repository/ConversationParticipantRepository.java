package com.jlsp.backend.chat.repository;

import com.jlsp.backend.chat.entity.ConversationParticipant;
import com.jlsp.backend.chat.entity.ConversationParticipantId;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Collection;
import java.util.List;

@Repository
public interface ConversationParticipantRepository
        extends JpaRepository<ConversationParticipant, ConversationParticipantId> {

    /** Trạng thái đọc của mọi người tham gia trong nhiều hội thoại (một truy vấn cho cả trang Inbox). */
    List<ConversationParticipant> findByIdConversationIdIn(Collection<Long> conversationIds);

    /**
     * Đặt mốc đã đọc bằng một câu UPDATE, không cần SELECT nạp entity trước.
     * Trả về số dòng đã cập nhật (0 nếu người này chưa có bản ghi participant).
     */
    @Modifying
    @Query("UPDATE ConversationParticipant p SET p.lastReadMessageId = :messageId " +
            "WHERE p.id.conversationId = :conversationId AND p.id.userId = :userId")
    int updateLastReadMessageId(@Param("conversationId") Long conversationId,
                                @Param("userId") Long userId,
                                @Param("messageId") Long messageId);

    /**
     * Tổng số tin nhắn chưa đọc của người dùng trên mọi hội thoại (badge Inbox).
     */
    @Query("SELECT COUNT(m) FROM ConversationParticipant p, Message m " +
            "WHERE p.id.userId = :userId AND m.conversation.id = p.id.conversationId " +
            "AND m.sender.id <> :userId AND m.id > COALESCE(p.lastReadMessageId, 0) " +
            "AND m.id > COALESCE(p.clearedMessageId, 0)")
    long countUnreadMessages(@Param("userId") Long userId);
}
