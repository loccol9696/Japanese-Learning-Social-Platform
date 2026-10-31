package com.jlsp.backend.subscription.dto.request;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import lombok.Data;

import java.math.BigDecimal;

/** Nội dung SePay gửi tới webhook khi có biến động số dư. Chỉ lấy các trường cần dùng. */
@Data
@JsonIgnoreProperties(ignoreUnknown = true)
public class SepayWebhookPayload {

    /** Mã giao dịch của SePay, duy nhất. */
    private Long id;
    private String gateway;
    private String transactionDate;
    private String accountNumber;
    private String code;
    private String content;
    /** "in" (tiền vào) hoặc "out" (tiền ra). */
    private String transferType;
    private BigDecimal transferAmount;
    private String referenceCode;
    private String description;
}
