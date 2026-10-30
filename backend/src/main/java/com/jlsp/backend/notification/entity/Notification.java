package com.jlsp.backend.notification.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

/**
 * Một thông báo gửi tới một người. Không đặt khóa ngoại tới video, bình luận hay người
 * thực hiện để việc xoá chúng không bị chặn; app hiển thị "không còn khả dụng" khi thiếu.
 */
@Entity
@Table(name = "notifications",
        indexes = {
                @Index(name = "idx_notifications_recipient_created", columnList = "recipient_id, created_at"),
                @Index(name = "idx_notifications_comment", columnList = "comment_id")
        },
        uniqueConstraints = @UniqueConstraint(name = "uk_notifications_dedupe",
                columnNames = {"recipient_id", "dedupe_key"}))
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Notification {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "recipient_id", nullable = false)
    private Long recipientId;

    /** Người thực hiện; null với thông báo hệ thống. */
    @Column(name = "actor_id")
    private Long actorId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 30)
    private NotificationType type;

    @Column(name = "video_id")
    private Long videoId;

    @Column(name = "comment_id")
    private Long commentId;

    /** Đoạn bình luận hoặc lý do từ chối, lưu lại vì nguồn gốc có thể bị sửa hoặc xoá. */
    @Column(columnDefinition = "TEXT")
    private String detail;

    /** Khoá chống trùng (vd. một người thích đi thích lại một video chỉ báo một lần). */
    @Column(name = "dedupe_key", length = 100)
    private String dedupeKey;

    @Column(name = "read_at")
    private LocalDateTime readAt;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @PrePersist
    protected void onCreate() {
        createdAt = LocalDateTime.now();
    }
}
