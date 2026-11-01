package com.jlsp.backend.block.entity;

import com.jlsp.backend.user.entity.User;
import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

/**
 * Người dùng {@code blocker} đã chặn {@code blocked}. Khóa chính (blocker_id, blocked_id) phục vụ
 * truy vấn "tôi đã chặn ai"; index thứ hai phục vụ "ai đã chặn tôi".
 */
@Entity
@Table(name = "user_blocks",
        indexes = @Index(name = "idx_user_blocks_blocked_id", columnList = "blocked_id"))
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class UserBlock {

    @EmbeddedId
    private UserBlockId id;

    @ManyToOne(fetch = FetchType.LAZY)
    @MapsId("blockerId")
    @JoinColumn(name = "blocker_id", nullable = false)
    private User blocker;

    @ManyToOne(fetch = FetchType.LAZY)
    @MapsId("blockedId")
    @JoinColumn(name = "blocked_id", nullable = false)
    private User blocked;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = LocalDateTime.now();
    }
}
