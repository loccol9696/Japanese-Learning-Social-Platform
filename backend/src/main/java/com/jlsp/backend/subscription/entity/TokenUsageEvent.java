package com.jlsp.backend.subscription.entity;

import com.jlsp.backend.user.entity.User;
import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDate;
import java.time.LocalDateTime;

/**
 * Một lần trừ token của một người dùng cho một tính năng AI. {@link UserDailyTokenUsage} vẫn là nguồn chính để
 * kiểm hạn mức theo ngày; bảng này chỉ để thống kê (dùng bao nhiêu, cho tính năng nào, vào ngày nào).
 */
@Entity
@Table(name = "token_usage_events", indexes = {
        @Index(name = "idx_token_events_user_date", columnList = "user_id, usage_date")
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class TokenUsageEvent {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 30)
    private TokenFeature feature;

    @Column(nullable = false)
    private Integer tokens;

    /** Ngày tính hạn mức (theo giờ máy chủ), cùng cách tính với {@link UserDailyTokenUsage#getUsageDate()}. */
    @Column(name = "usage_date", nullable = false)
    private LocalDate usageDate;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @PrePersist
    protected void onCreate() {
        createdAt = LocalDateTime.now();
    }
}
