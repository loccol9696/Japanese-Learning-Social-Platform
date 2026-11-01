package com.jlsp.backend.chat.entity;

import com.jlsp.backend.user.entity.User;
import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

/**
 * Token FCM của một thiết bị. Mỗi token chỉ thuộc một người: đăng nhập tài khoản khác
 * trên cùng máy thì token được gán lại.
 */
@Entity
@Table(name = "device_tokens",
        indexes = @Index(name = "idx_device_tokens_user_id", columnList = "user_id"),
        uniqueConstraints = @UniqueConstraint(name = "uk_device_token", columnNames = "token"))
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class DeviceToken {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(nullable = false, length = 512)
    private String token;

    @Column(nullable = false, length = 20)
    private String platform;

    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;

    @PrePersist
    @PreUpdate
    protected void touch() {
        this.updatedAt = LocalDateTime.now();
    }
}
