package com.jlsp.backend.chat.entity;

import com.jlsp.backend.user.entity.User;
import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

/**
 * Hội thoại 1-1. Cặp người dùng luôn được lưu theo thứ tự (userLow.id < userHigh.id)
 * để ràng buộc unique đảm bảo mỗi cặp chỉ có đúng một hội thoại.
 */
@Entity
@Table(name = "conversations",
        uniqueConstraints = @UniqueConstraint(name = "uk_conversation_pair",
                columnNames = {"user_low_id", "user_high_id"}))
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Conversation {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_low_id", nullable = false)
    private User userLow;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_high_id", nullable = false)
    private User userHigh;

    /**
     * Tin nhắn mới nhất (hiển thị ở danh sách hội thoại)
     */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "last_message_id")
    private Message lastMessage;

    /**
     * Thời điểm có tin nhắn gần nhất — dùng để sắp xếp danh sách hội thoại
     */
    @Column(name = "last_message_at")
    private LocalDateTime lastMessageAt;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = LocalDateTime.now();
        if (this.lastMessageAt == null) {
            this.lastMessageAt = this.createdAt;
        }
    }

    public User getOtherUser(Long userId) {
        return userLow.getId().equals(userId) ? userHigh : userLow;
    }
}
