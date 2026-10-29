package com.jlsp.backend.subscription.dto.response;

import lombok.*;

import java.time.LocalDateTime;

/** Gói thành viên hiện tại của người dùng kèm hạn mức token AI trong ngày. */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class SubscriptionStatusResponse {

    private boolean vip;
    private Long planId;
    private String planCode;
    private String planName;
    /** Hết hạn; null khi là gói trọn đời hoặc chưa có gói trả phí. */
    private LocalDateTime expiresAt;
    private boolean lifetime;
    private int remainingDays;
    private int dailyTokenLimit;
    private int tokensUsedToday;
    private int tokensRemainingToday;
}
