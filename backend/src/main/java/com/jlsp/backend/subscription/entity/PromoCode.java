package com.jlsp.backend.subscription.entity;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Entity
@Table(name = "promo_codes")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class PromoCode {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true, length = 50)
    private String code; // e.g. JLSP10, KOTOBA, HARU2026

    @Column(columnDefinition = "TEXT")
    private String description;

    @Column(name = "discount_percent")
    @Builder.Default
    private Integer discountPercent = 0; // % giảm (0-100)

    @Column(name = "discount_amount")
    @Builder.Default
    private BigDecimal discountAmount = BigDecimal.ZERO; // Tiền giảm trực tiếp (VND)

    @Column(name = "min_order_amount")
    @Builder.Default
    private BigDecimal minOrderAmount = BigDecimal.ZERO;

    @Column(name = "max_uses", nullable = false)
    @Builder.Default
    private Integer maxUses = 100; // Giới hạn lượt dùng tối đa

    @Column(name = "used_count", nullable = false)
    @Builder.Default
    private Integer usedCount = 0; // Số lượt đã dùng

    @Column(name = "start_date")
    private LocalDateTime startDate;

    @Column(name = "end_date")
    private LocalDateTime endDate;

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
        if (this.code != null) {
            this.code = this.code.trim().toUpperCase();
        }
        if (this.discountPercent == null) this.discountPercent = 0;
        if (this.discountAmount == null) this.discountAmount = BigDecimal.ZERO;
        if (this.minOrderAmount == null) this.minOrderAmount = BigDecimal.ZERO;
        if (this.maxUses == null) this.maxUses = 100;
        if (this.usedCount == null) this.usedCount = 0;
        if (this.isActive == null) this.isActive = true;
    }

    @PreUpdate
    protected void onUpdate() {
        this.updatedAt = LocalDateTime.now();
        if (this.code != null) {
            this.code = this.code.trim().toUpperCase();
        }
    }
}
