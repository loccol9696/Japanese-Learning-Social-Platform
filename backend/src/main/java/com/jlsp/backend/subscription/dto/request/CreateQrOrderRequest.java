package com.jlsp.backend.subscription.dto.request;

import lombok.*;
import java.math.BigDecimal;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CreateQrOrderRequest {

    private Long planId;

    private String planCode;

    private Long userId;

    private String orderCode;

    private BigDecimal amount;

    private String promoCode;
}
