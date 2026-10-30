package com.jlsp.backend.notification.repository;

import com.jlsp.backend.notification.entity.Notification;
import com.jlsp.backend.notification.entity.NotificationType;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.Collection;

@Repository
public interface NotificationRepository extends JpaRepository<Notification, Long> {

    Page<Notification> findByRecipientIdAndTypeInOrderByCreatedAtDescIdDesc(
            Long recipientId, Collection<NotificationType> types, Pageable pageable);

    long countByRecipientIdAndReadAtIsNull(Long recipientId);

    boolean existsByRecipientIdAndDedupeKey(Long recipientId, String dedupeKey);

    @Modifying
    @Query("UPDATE Notification n SET n.readAt = :now " +
            "WHERE n.id = :id AND n.recipientId = :recipientId AND n.readAt IS NULL")
    int markRead(@Param("id") Long id, @Param("recipientId") Long recipientId, @Param("now") LocalDateTime now);

    @Modifying
    @Query("UPDATE Notification n SET n.readAt = :now WHERE n.recipientId = :recipientId AND n.readAt IS NULL")
    int markAllRead(@Param("recipientId") Long recipientId, @Param("now") LocalDateTime now);

    @Modifying
    @Query("DELETE FROM Notification n WHERE n.commentId IN :commentIds")
    void deleteByCommentIds(@Param("commentIds") Collection<Long> commentIds);
}
