package com.jlsp.backend.subscription.dto.request;

import jakarta.validation.constraints.NotBlank;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class PromoCodeRequest {

    @NotBlank(message = "Mã khuyến mãi không được để trống")
    private String code;

    private String description;

    private Integer discountPercent;

    private BigDecimal discountAmount;

    private BigDecimal minOrderAmount;

    private Integer maxUses;

    private LocalDateTime startDate;

    private LocalDateTime endDate;

    private Boolean isActive;
}
