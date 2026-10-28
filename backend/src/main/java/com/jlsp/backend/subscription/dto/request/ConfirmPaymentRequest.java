package com.jlsp.backend.subscription.dto.request;

import lombok.*;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ConfirmPaymentRequest {

    private String verificationCode;
    private String orderCode;
}
