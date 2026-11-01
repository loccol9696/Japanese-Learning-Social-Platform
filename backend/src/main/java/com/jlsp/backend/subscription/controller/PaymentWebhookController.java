package com.jlsp.backend.subscription.controller;

import com.jlsp.backend.subscription.dto.request.SepayWebhookPayload;
import com.jlsp.backend.subscription.payment.PaymentProperties;
import com.jlsp.backend.subscription.payment.WebhookResult;
import com.jlsp.backend.subscription.service.PaymentService;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

/**
 * Webhook nhận biến động số dư từ SePay. Đường dẫn công khai nhưng bắt buộc header
 * {@code Authorization: Apikey <SEPAY_WEBHOOK_KEY>}; thiếu hoặc sai khoá là 401, chưa cấu hình khoá thì từ chối tất cả.
 *
 * <p>Mọi giao dịch hợp lệ đều trả 200 với {@code success=true} (đã nhận) dù có khớp đơn hay không, để SePay không gửi
 * lại vô ích; lỗi tạm thời (DB...) thì để lỗi 5xx tự lan ra để SePay gửi lại. Không ghi nguyên payload vào log.
 */
@RestController
@RequestMapping("/api/v1/payments/webhook")
@RequiredArgsConstructor
public class PaymentWebhookController {

    private static final Logger log = LoggerFactory.getLogger(PaymentWebhookController.class);
    private static final String SCHEME = "Apikey ";

    private final PaymentService paymentService;
    private final PaymentProperties props;

    @PostMapping("/sepay")
    public ResponseEntity<Map<String, Object>> sepay(
            @RequestHeader(value = "Authorization", required = false) String authorization,
            @RequestBody SepayWebhookPayload payload) {
        if (!props.webhookKeyMatches(extractKey(authorization))) {
            log.warn("Webhook SePay bị từ chối: sai hoặc thiếu khoá");
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(Map.of("success", false));
        }
        WebhookResult result;
        try {
            result = paymentService.handleSepayWebhook(payload);
        } catch (DataIntegrityViolationException duplicate) {
            // Hai webhook cùng một giao dịch chạy đồng thời: ràng buộc duy nhất đã chặn bản thứ hai.
            result = WebhookResult.DUPLICATE;
        }
        log.info("Webhook SePay xử lý: {}", result);
        return ResponseEntity.ok(Map.of("success", true));
    }

    private static String extractKey(String authorization) {
        if (authorization == null || authorization.length() <= SCHEME.length()
                || !authorization.regionMatches(true, 0, SCHEME, 0, SCHEME.length())) {
            return null;
        }
        return authorization.substring(SCHEME.length()).trim();
    }
}
