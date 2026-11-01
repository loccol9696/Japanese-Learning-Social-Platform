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
    /** Mã chuyển khoản (cũng là mã đơn): người dùng phải ghi đúng mã này trong nội dung chuyển khoản. */
    private String transferMemo;
    private Long userId;
    private String username;
    private String userEmail;
    private Long planId;
    private String planName;
    private Integer dailyTokenLimit;
    private BigDecimal amount;
    private BigDecimal paidAmount;
    private String paymentMethod;
    private SubscriptionOrder.OrderStatus status;
    private String qrUrl;
    private String bankName;
    private String accountNo;
    private String accountName;
    private LocalDateTime expiresAt;
    private LocalDateTime createdAt;
    private LocalDateTime completedAt;
}
