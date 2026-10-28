package com.jlsp.backend.subscription.controller;

import com.jlsp.backend.common.response.ApiResponse;
import com.jlsp.backend.common.response.PageResponse;
import com.jlsp.backend.common.security.CurrentUser;
import com.jlsp.backend.subscription.dto.request.ConfirmPaymentRequest;
import com.jlsp.backend.subscription.dto.request.CreateQrOrderRequest;
import com.jlsp.backend.subscription.dto.response.SubscriptionOrderResponse;
import com.jlsp.backend.subscription.dto.response.TokenQuotaResponse;
import com.jlsp.backend.subscription.entity.SubscriptionOrder;
import com.jlsp.backend.subscription.service.SubscriptionService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping({"/api/v1/payments", "/api/v1/subscriptions/payments", "/api/v1/subscriptions", "/api/payment"})
@RequiredArgsConstructor
@Slf4j
public class PaymentController {

    private final SubscriptionService subscriptionService;

    @PostMapping({"/create-order", "/create-qr-order", "/checkout"})
    public ResponseEntity<ApiResponse<SubscriptionOrderResponse>> createQrOrder(
            @Valid @RequestBody CreateQrOrderRequest request) {
        Long authUserId = CurrentUser.idOrNull();
        if (request.getUserId() == null && authUserId != null) {
            request.setUserId(authUserId);
        }
        SubscriptionOrderResponse response = subscriptionService.createQrOrder(request);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.success(HttpStatus.CREATED.value(), "Tạo đơn hàng thanh toán QR thành công", response));
    }

    @PostMapping("/confirm")
    public ResponseEntity<ApiResponse<SubscriptionOrderResponse>> confirmPayment(
            @RequestBody ConfirmPaymentRequest request) {
        SubscriptionOrderResponse response = subscriptionService.confirmPayment(request);
        return ResponseEntity.ok(ApiResponse.success(200, "Xác nhận thanh toán thành công! Gói VIP đã được kích hoạt.", response));
    }

    @PostMapping({"/admin/approve/{orderCode}", "/approve/{orderCode}"})
    public ResponseEntity<ApiResponse<SubscriptionOrderResponse>> adminApprove(
            @PathVariable String orderCode) {
        ConfirmPaymentRequest req = new ConfirmPaymentRequest();
        req.setOrderCode(orderCode);
        SubscriptionOrderResponse response = subscriptionService.confirmPayment(req);
        return ResponseEntity.ok(ApiResponse.success(200, "Duyệt thanh toán thành công cho đơn " + orderCode + "! Gói VIP đã được kích hoạt.", response));
    }

    @PostMapping({"/webhook/sepay", "/sepay-webhook"})
    public ResponseEntity<ApiResponse<Object>> handleSepayWebhook(@RequestBody Map<String, Object> payload) {
        log.info("Received SePay Webhook payload: {}", payload);
        try {
            String content = String.valueOf(payload.getOrDefault("content", ""));
            String description = String.valueOf(payload.getOrDefault("description", ""));
            String code = String.valueOf(payload.getOrDefault("code", ""));
            String combined = content + " " + description + " " + code + " " + payload;

            // 1. Tìm mã đơn dạng TX-xxxxxx hoặc TXxxxxxx hoặc TX xxxxxx
            java.util.regex.Pattern txPattern = java.util.regex.Pattern.compile("TX[-\\s]*([0-9]{4,8})", java.util.regex.Pattern.CASE_INSENSITIVE);
            java.util.regex.Matcher txMatcher = txPattern.matcher(combined);
            if (txMatcher.find()) {
                String orderCode = "TX-" + txMatcher.group(1);
                ConfirmPaymentRequest req = new ConfirmPaymentRequest();
                req.setOrderCode(orderCode);
                try {
                    subscriptionService.confirmPayment(req);
                    log.info("SePay Webhook confirmed order by TX code: {}", orderCode);
                    return ResponseEntity.ok(ApiResponse.<Object>success(200, "Webhook xử lý thành công đơn " + orderCode, orderCode));
                } catch (Exception ex) {
                    log.warn("Order {} not found directly, trying fallback: {}", orderCode, ex.getMessage());
                }
            }

            // 2. Tìm mã xác nhận dạng JLSP-xxxxx
            java.util.regex.Pattern jlspPattern = java.util.regex.Pattern.compile("JLSP[-\\s]*([0-9]{4,8})", java.util.regex.Pattern.CASE_INSENSITIVE);
            java.util.regex.Matcher jlspMatcher = jlspPattern.matcher(combined);
            if (jlspMatcher.find()) {
                String digits = jlspMatcher.group(1);
                ConfirmPaymentRequest req = new ConfirmPaymentRequest();
                req.setVerificationCode("JLSP-" + digits);
                req.setOrderCode("TX-" + digits);
                try {
                    SubscriptionOrderResponse confirmed = subscriptionService.confirmPayment(req);
                    log.info("SePay Webhook confirmed order by JLSP digits: {}", confirmed.getOrderCode());
                    return ResponseEntity.ok(ApiResponse.<Object>success(200, "Webhook xử lý thành công đơn " + confirmed.getOrderCode(), confirmed.getOrderCode()));
                } catch (Exception ex) {
                    log.warn("JLSP code {} not matched directly: {}", digits, ex.getMessage());
                }
            }

            // 3. Fallback: Tự động khớp đơn PENDING mới nhất khi SePay bắn biến động số dư tiền vào
            String transferType = String.valueOf(payload.getOrDefault("transferType", "in"));
            if (!"out".equalsIgnoreCase(transferType)) {
                ConfirmPaymentRequest fallbackReq = new ConfirmPaymentRequest();
                fallbackReq.setOrderCode("LATEST_PENDING");
                SubscriptionOrderResponse confirmed = subscriptionService.confirmPayment(fallbackReq);
                log.info("SePay Webhook confirmed latest PENDING order via fallback: {}", confirmed.getOrderCode());
                return ResponseEntity.ok(ApiResponse.<Object>success(200, "Webhook tự động khớp đơn chờ mới nhất " + confirmed.getOrderCode(), confirmed.getOrderCode()));
            }
        } catch (Exception e) {
            log.error("SePay Webhook error: {}", e.getMessage());
            return ResponseEntity.ok(ApiResponse.<Object>success(200, "Webhook đã ghi nhận: " + e.getMessage(), null));
        }
        return ResponseEntity.ok(ApiResponse.<Object>success(200, "Webhook nhận thành công nhưng không tìm thấy mã đơn hợp lệ", null));
    }

    @PostMapping({"/webhook/casso", "/casso-webhook"})
    public ResponseEntity<ApiResponse<Object>> handleCassoWebhook(@RequestBody Map<String, Object> payload) {
        log.info("Received Casso Webhook payload: {}", payload);
        try {
            Object dataObj = payload.get("data");
            java.util.regex.Pattern pattern = java.util.regex.Pattern.compile("TX[-\\s]*([0-9]{4,8})", java.util.regex.Pattern.CASE_INSENSITIVE);
            if (dataObj instanceof java.util.List<?> list) {
                for (Object item : list) {
                    if (item instanceof Map<?, ?> tx) {
                        String description = tx.get("description") != null ? tx.get("description").toString() : "";
                        java.util.regex.Matcher matcher = pattern.matcher(description);
                        if (matcher.find()) {
                            String orderCode = "TX-" + matcher.group(1);
                            ConfirmPaymentRequest req = new ConfirmPaymentRequest();
                            req.setOrderCode(orderCode);
                            subscriptionService.confirmPayment(req);
                            return ResponseEntity.ok(ApiResponse.<Object>success(200, "Casso Webhook xử lý thành công đơn " + orderCode, orderCode));
                        }
                    }
                }
            }
        } catch (Exception e) {
            log.error("Casso Webhook error: {}", e.getMessage());
            return ResponseEntity.ok(ApiResponse.<Object>success(200, "Lỗi xử lý Casso webhook: " + e.getMessage(), null));
        }
        return ResponseEntity.ok(ApiResponse.<Object>success(200, "Casso Webhook nhận thành công", null));
    }

    @GetMapping("/order-status/{orderCode}")
    public ResponseEntity<ApiResponse<SubscriptionOrderResponse>> getOrderStatus(
            @PathVariable String orderCode) {
        SubscriptionOrderResponse response = subscriptionService.getOrderStatus(orderCode);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    @GetMapping({"/my-status", "/status"})
    public ResponseEntity<ApiResponse<Map<String, Object>>> getMyStatus(
            @RequestHeader(value = "X-User-Id", required = false) Long headerUserId,
            @RequestParam(value = "userId", required = false) Long paramUserId) {
        Long authUserId = CurrentUser.idOrNull();
        Long userId = headerUserId != null ? headerUserId : (paramUserId != null ? paramUserId : (authUserId != null ? authUserId : 1L));
        Map<String, Object> status = subscriptionService.getUserSubscriptionStatus(userId);
        return ResponseEntity.ok(ApiResponse.success(status));
    }

    @GetMapping("/history")
    public ResponseEntity<ApiResponse<PageResponse<SubscriptionOrderResponse>>> getHistory(
            @RequestParam(value = "status", required = false) SubscriptionOrder.OrderStatus status,
            @PageableDefault(size = 15, sort = "createdAt", direction = Sort.Direction.DESC) Pageable pageable) {
        PageResponse<SubscriptionOrderResponse> response = subscriptionService.getSubscriptionHistory(status, pageable);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    @GetMapping({"/my-quota", "/token-quota"})
    public ResponseEntity<ApiResponse<TokenQuotaResponse>> getTokenQuota(
            @RequestHeader(value = "X-User-Id", required = false) Long headerUserId,
            @RequestParam(value = "userId", required = false) Long paramUserId) {
        Long authUserId = CurrentUser.idOrNull();
        Long userId = headerUserId != null ? headerUserId : (paramUserId != null ? paramUserId : (authUserId != null ? authUserId : 1L));
        TokenQuotaResponse response = subscriptionService.checkTokenQuota(userId);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    @PostMapping("/sepay-token")
    public ResponseEntity<ApiResponse<Map<String, Object>>> saveSepayToken(
            @RequestBody Map<String, String> body) {
        String token = body.getOrDefault("token", body.getOrDefault("apiToken", ""));
        Map<String, Object> status = subscriptionService.saveSepayApiToken(token);
        return ResponseEntity.ok(ApiResponse.success(200, "Đã lưu SEPAY_API_TOKEN và kích hoạt chế độ tự động đọc giao dịch trực tiếp từ SePay API!", status));
    }

    @GetMapping("/sepay-token/status")
    public ResponseEntity<ApiResponse<Map<String, Object>>> getSepayTokenStatus() {
        return ResponseEntity.ok(ApiResponse.success(subscriptionService.getSepayTokenStatus()));
    }
}
