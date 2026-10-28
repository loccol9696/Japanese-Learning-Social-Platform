package com.jlsp.backend.subscription.dto.request;

import lombok.*;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CreateQrOrderRequest {

    private Long planId;

    private String planCode;

    private Long userId;

    private String orderCode;
}
