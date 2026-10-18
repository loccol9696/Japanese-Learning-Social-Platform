package com.jlsp.backend.subscription.dto.request;

import jakarta.validation.constraints.NotBlank;
import lombok.*;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ConfirmPaymentRequest {

    @NotBlank(message = "Mã xác nhận dưới QR không được để trống")
    private String verificationCode;

    private String orderCode;
}
