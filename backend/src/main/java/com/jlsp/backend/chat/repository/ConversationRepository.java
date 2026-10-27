package com.jlsp.backend.chat.repository;

import com.jlsp.backend.chat.entity.Conversation;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface ConversationRepository extends JpaRepository<Conversation, Long> {

    Optional<Conversation> findByUserLowIdAndUserHighId(Long userLowId, Long userHighId);

    /**
     * Danh sách hội thoại đã có tin nhắn của một người dùng, mới nhất trước, trừ hội thoại người này đã xoá.
     */
    @EntityGraph(attributePaths = {"userLow", "userHigh", "lastMessage"})
    @Query("SELECT c FROM Conversation c WHERE (c.userLow.id = :userId OR c.userHigh.id = :userId) " +
            "AND c.lastMessage IS NOT NULL " +
            // Ẩn hội thoại mà người này đã xoá và chưa có tin mới hơn mốc xoá.
            "AND NOT EXISTS (SELECT 1 FROM ConversationParticipant p WHERE p.id.conversationId = c.id " +
            "AND p.id.userId = :userId AND p.clearedBeforeMessageId IS NOT NULL " +
            "AND p.clearedBeforeMessageId >= c.lastMessage.id) " +
            "ORDER BY c.lastMessageAt DESC, c.id DESC")
    Page<Conversation> findActiveByUserId(@Param("userId") Long userId, Pageable pageable);

    @EntityGraph(attributePaths = {"userLow", "userHigh", "lastMessage"})
    @Query("SELECT c FROM Conversation c WHERE c.id = :id")
    Optional<Conversation> findDetailById(@Param("id") Long id);
}
