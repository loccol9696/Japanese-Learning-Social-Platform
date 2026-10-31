package com.jlsp.backend.subscription.dto.request;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import lombok.*;

import java.math.BigDecimal;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@JsonIgnoreProperties(ignoreUnknown = true)
public class BankWebhookRequest {

    /** Nội dung chuyển khoản (SePay / Casso / VietQR), ví dụ: "JLSP_PAYMENT_TX-123456_JLSP-89123" */
    private String content;

    /** Mô tả giao dịch ngân hàng */
    private String description;

    /** Mã đơn hàng (nếu có) */
    private String orderCode;

    /** Mã xác nhận 6 số dưới QR (nếu có) */
    private String verificationCode;

    /** Số tiền thực nhận */
    private BigDecimal transferAmount;

    /** Số tiền (trường alias) */
    private BigDecimal amount;

    /** Tên cổng ngân hàng gửi webhook (MB, VCB, SePay, PayOS...) */
    private String gateway;

    /** Mã tham chiếu ngân hàng */
    private String referenceCode;
}

