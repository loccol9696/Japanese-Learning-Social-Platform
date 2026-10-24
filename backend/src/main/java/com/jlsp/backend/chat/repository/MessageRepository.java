package com.jlsp.backend.chat.repository;

import com.jlsp.backend.chat.entity.Message;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface MessageRepository extends JpaRepository<Message, Long> {

    /** Trang tin nhắn mới nhất (mới nhất trước). */
    @EntityGraph(attributePaths = "sender")
    List<Message> findByConversationIdOrderByIdDesc(Long conversationId, Pageable pageable);

    /** Tin nhắn cũ hơn cursor beforeId (kéo lên để xem thêm). */
    @EntityGraph(attributePaths = "sender")
    List<Message> findByConversationIdAndIdLessThanOrderByIdDesc(Long conversationId, Long beforeId,
                                                                Pageable pageable);

    @EntityGraph(attributePaths = "sender")
    Optional<Message> findBySenderIdAndClientMsgId(Long senderId, String clientMsgId);

    /** lastReadId truyền 0 nếu người dùng chưa đọc tin nào. */
    @Query("SELECT COUNT(m) FROM Message m WHERE m.conversation.id = :conversationId " +
            "AND m.sender.id <> :userId AND m.id > :lastReadId")
    long countUnread(@Param("conversationId") Long conversationId,
                     @Param("userId") Long userId,
                     @Param("lastReadId") Long lastReadId);

    @Query("SELECT MAX(m.id) FROM Message m WHERE m.conversation.id = :conversationId")
    Long findLatestId(@Param("conversationId") Long conversationId);
}
