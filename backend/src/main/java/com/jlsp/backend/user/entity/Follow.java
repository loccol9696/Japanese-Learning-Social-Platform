package com.jlsp.backend.user.entity;

import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

/**
 * Khóa chính (follower_id, following_id) chỉ phục vụ truy vấn theo người theo dõi; index thứ hai
 * phục vụ các truy vấn theo người được theo dõi (đếm / liệt kê follower, kiểm tra follow lẫn nhau).
 */
@Entity
@Table(name = "follows",
        indexes = @Index(name = "idx_follows_following_id", columnList = "following_id"))
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Follow {

    @EmbeddedId
    private FollowId id;

    @ManyToOne(fetch = FetchType.LAZY)
    @MapsId("followerId")
    @JoinColumn(name = "follower_id", nullable = false)
    private User follower;

    @ManyToOne(fetch = FetchType.LAZY)
    @MapsId("followingId")
    @JoinColumn(name = "following_id", nullable = false)
    private User following;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = LocalDateTime.now();
    }
}
