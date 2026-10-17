package com.jlsp.backend.subscription.dto.response;

import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class SubscriptionPlanResponse {

    private Long id;
    private String name;
    private String code;
    private BigDecimal price;
    private Integer durationDays;
    private Integer dailyTokenLimit;
    private String description;
    private String features;
    private Boolean isActive;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}
