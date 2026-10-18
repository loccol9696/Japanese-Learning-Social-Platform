package com.jlsp.backend.subscription.controller;

import com.jlsp.backend.common.response.ApiResponse;
import com.jlsp.backend.common.response.PageResponse;
import com.jlsp.backend.subscription.dto.request.ConfirmPaymentRequest;
import com.jlsp.backend.subscription.dto.request.CreateQrOrderRequest;
import com.jlsp.backend.subscription.dto.response.SubscriptionOrderResponse;
import com.jlsp.backend.subscription.dto.response.TokenQuotaResponse;
import com.jlsp.backend.subscription.entity.SubscriptionOrder;
import com.jlsp.backend.subscription.service.SubscriptionService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/payments")
@RequiredArgsConstructor
public class PaymentController {

    private final SubscriptionService subscriptionService;

    @PostMapping({"/create-order", "/create-qr-order"})
    public ResponseEntity<ApiResponse<SubscriptionOrderResponse>> createQrOrder(
            @Valid @RequestBody CreateQrOrderRequest request) {
        SubscriptionOrderResponse response = subscriptionService.createQrOrder(request);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.success(HttpStatus.CREATED.value(), "Tạo đơn hàng thanh toán QR thành công", response));
    }

    @PostMapping("/confirm")
    public ResponseEntity<ApiResponse<SubscriptionOrderResponse>> confirmPayment(
            @Valid @RequestBody ConfirmPaymentRequest request) {
        SubscriptionOrderResponse response = subscriptionService.confirmPayment(request);
        return ResponseEntity.ok(ApiResponse.success(200, "Xác nhận thanh toán thành công! Gói VIP đã được kích hoạt.", response));
    }

    @GetMapping("/order-status/{orderCode}")
    public ResponseEntity<ApiResponse<SubscriptionOrderResponse>> getOrderStatus(
            @PathVariable String orderCode) {
        SubscriptionOrderResponse response = subscriptionService.getOrderStatus(orderCode);
        return ResponseEntity.ok(ApiResponse.success(response));
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
        Long userId = headerUserId != null ? headerUserId : (paramUserId != null ? paramUserId : 1L);
        TokenQuotaResponse response = subscriptionService.checkTokenQuota(userId);
        return ResponseEntity.ok(ApiResponse.success(response));
    }
}
