package com.jlsp.backend.subscription.dto.response;

import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class PromoCodeResponse {

    private Long id;
    private String code;
    private String description;
    private Integer discountPercent;
    private BigDecimal discountAmount;
    private BigDecimal minOrderAmount;
    private Integer maxUses;
    private Integer usedCount;
    private LocalDateTime startDate;
    private LocalDateTime endDate;
    private Boolean isActive;
    private String status; // ACTIVE, EXPIRED, EXHAUSTED, DISABLED
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}
