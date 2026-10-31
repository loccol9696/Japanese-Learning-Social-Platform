package com.jlsp.backend.chat.repository;

import com.jlsp.backend.chat.entity.Message;
import com.jlsp.backend.common.repository.IdCount;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Collection;
import java.util.List;
import java.util.Optional;

@Repository
public interface MessageRepository extends JpaRepository<Message, Long> {

    /** Trang tin nhắn mới nhất (mới nhất trước), chỉ lấy tin mới hơn mốc xoá floorId. */
    @EntityGraph(attributePaths = "sender")
    List<Message> findByConversationIdAndIdGreaterThanOrderByIdDesc(Long conversationId, Long floorId,
                                                                   Pageable pageable);

    /** Tin nhắn cũ hơn cursor beforeId (kéo lên để xem thêm), chỉ lấy tin mới hơn mốc xoá floorId. */
    @EntityGraph(attributePaths = "sender")
    List<Message> findByConversationIdAndIdGreaterThanAndIdLessThanOrderByIdDesc(
            Long conversationId, Long floorId, Long beforeId, Pageable pageable);

    /** Tin mới hơn cursor afterId, cũ nhất trước (đồng bộ phần đã lỡ sau khi mất kết nối). */
    @EntityGraph(attributePaths = "sender")
    List<Message> findByConversationIdAndIdGreaterThanOrderByIdAsc(Long conversationId, Long afterId,
                                                                  Pageable pageable);

    @EntityGraph(attributePaths = "sender")
    Optional<Message> findBySenderIdAndClientMsgId(Long senderId, String clientMsgId);

    /**
     * Số tin chưa đọc (tin của người kia, mới hơn mốc đã đọc và mốc xoá) của userId trong nhiều hội thoại
     * bằng một truy vấn cho cả trang Inbox. Hội thoại không còn tin chưa đọc sẽ không có dòng.
     */
    @Query("SELECT m.conversation.id AS id, COUNT(m) AS total FROM Message m " +
            "LEFT JOIN ConversationParticipant p " +
            "ON p.id.conversationId = m.conversation.id AND p.id.userId = :userId " +
            "WHERE m.conversation.id IN :conversationIds AND m.sender.id <> :userId " +
            "AND m.id > COALESCE(p.lastReadMessageId, 0) " +
            "AND m.id > COALESCE(p.clearedMessageId, 0) " +
            "GROUP BY m.conversation.id")
    List<IdCount> countUnreadByConversation(@Param("userId") Long userId,
                                            @Param("conversationIds") Collection<Long> conversationIds);

    @Query("SELECT MAX(m.id) FROM Message m WHERE m.conversation.id = :conversationId")
    Long findLatestId(@Param("conversationId") Long conversationId);
}
