package com.jlsp.backend.subscription.entity;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Entity
@Table(name = "subscription_plans")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class SubscriptionPlan {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 100)
    private String name;

    @Column(nullable = false, unique = true, length = 50)
    private String code; // e.g. FREE, PRO_MONTHLY, PRO_YEARLY, SPECIAL_VIP

    @Column(nullable = false)
    private BigDecimal price; // Giá VND

    @Column(name = "duration_days", nullable = false)
    private Integer durationDays; // Thời hạn sử dụng (ngày), vd 30, 365, 9999

    /**
     * Giới hạn Token AI theo ngày (cho tính năng trích xuất lời video, AI shadowing)
     */
    @Column(name = "daily_token_limit", nullable = false)
    private Integer dailyTokenLimit;

    @Column(columnDefinition = "TEXT")
    private String description;

    @Column(columnDefinition = "TEXT")
    private String features; // JSON or newline-separated features list

    @Column(name = "is_active", nullable = false)
    @Builder.Default
    private Boolean isActive = true;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    @PrePersist
    protected void onCreate() {
        this.createdAt = LocalDateTime.now();
        this.updatedAt = LocalDateTime.now();
        if (this.isActive == null) {
            this.isActive = true;
        }
    }

    @PreUpdate
    protected void onUpdate() {
        this.updatedAt = LocalDateTime.now();
    }
}
