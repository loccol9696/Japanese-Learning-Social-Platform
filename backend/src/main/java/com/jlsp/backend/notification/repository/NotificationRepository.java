package com.jlsp.backend.notification.repository;

import com.jlsp.backend.notification.entity.Notification;
import com.jlsp.backend.notification.entity.NotificationType;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Optional;

public interface NotificationRepository extends JpaRepository<Notification, Long> {

    @EntityGraph(attributePaths = "actor")
    Page<Notification> findByRecipientId(Long recipientId, Pageable pageable);

    @EntityGraph(attributePaths = "actor")
    Page<Notification> findByRecipientIdAndIsReadFalse(Long recipientId, Pageable pageable);

    long countByRecipientIdAndIsReadFalse(Long recipientId);

    Optional<Notification> findByIdAndRecipientId(Long id, Long recipientId);

    /** Chống thông báo trùng cho "thích video" (mỗi người chỉ một thông báo cho mỗi video). */
    boolean existsByRecipientIdAndActorIdAndTypeAndVideoId(
            Long recipientId, Long actorId, NotificationType type, Long videoId);

    /** Chống thông báo trùng cho "theo dõi" (bấm theo dõi / bỏ theo dõi liên tục). */
    boolean existsByRecipientIdAndActorIdAndType(Long recipientId, Long actorId, NotificationType type);

    @Modifying
    @Query("UPDATE Notification n SET n.isRead = true WHERE n.recipient.id = :userId AND n.isRead = false")
    int markAllRead(@Param("userId") Long userId);
}
