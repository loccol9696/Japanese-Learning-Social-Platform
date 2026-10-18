package com.jlsp.backend.subscription.dto.response;

import lombok.*;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class TokenRateDto {
    private Integer secondsPerToken;
    private String description;
}
