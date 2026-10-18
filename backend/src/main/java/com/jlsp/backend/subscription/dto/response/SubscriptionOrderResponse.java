package com.jlsp.backend.subscription.dto.response;

import com.jlsp.backend.subscription.entity.SubscriptionOrder;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class SubscriptionOrderResponse {

    private Long id;
    private String orderCode;
    private String verificationCode;
    private Long userId;
    private String username;
    private String userEmail;
    private Long planId;
    private String planName;
    private Integer dailyTokenLimit;
    private BigDecimal amount;
    private String paymentMethod;
    private SubscriptionOrder.OrderStatus status;
    private String qrUrl;
    private String paymentWebUrl;
    private LocalDateTime createdAt;
    private LocalDateTime completedAt;
}
