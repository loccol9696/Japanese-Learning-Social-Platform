package com.jlsp.backend.subscription.dto.response;

import lombok.*;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class TokenQuotaResponse {

    private Long userId;
    private String planName;
    private Integer dailyTokenLimit;
    private Integer tokensUsedToday;
    private Integer tokensRemainingToday;
}
