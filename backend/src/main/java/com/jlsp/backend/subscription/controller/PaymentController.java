package com.jlsp.backend.subscription.controller;

import com.jlsp.backend.common.response.ApiResponse;
import com.jlsp.backend.common.response.PageResponse;
import com.jlsp.backend.common.security.CurrentUser;
import com.jlsp.backend.subscription.dto.request.CreateOrderRequest;
import com.jlsp.backend.subscription.dto.response.SubscriptionOrderResponse;
import com.jlsp.backend.subscription.dto.response.SubscriptionStatusResponse;
import com.jlsp.backend.subscription.dto.response.TokenQuotaResponse;
import com.jlsp.backend.subscription.service.PaymentService;
import com.jlsp.backend.subscription.service.SubscriptionService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

/**
 * API thanh toán của người dùng. Mọi endpoint cần đăng nhập và chỉ làm việc với đơn của chính người gọi: danh tính
 * lấy từ access token, không nhận userId từ body, header hay tham số.
 */
@RestController
@RequestMapping("/api/v1/payments")
@RequiredArgsConstructor
public class PaymentController {

    private final PaymentService paymentService;
    private final SubscriptionService subscriptionService;

    @PostMapping("/orders")
    public ResponseEntity<ApiResponse<SubscriptionOrderResponse>> createOrder(@RequestBody CreateOrderRequest request) {
        SubscriptionOrderResponse response = paymentService.createOrder(CurrentUser.requireId(), request);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.success(HttpStatus.CREATED.value(), "Tạo đơn thanh toán thành công", response));
    }

    /** Chỉ đọc: không bao giờ tự kích hoạt gói; gói chỉ được kích hoạt bởi webhook ngân hàng hoặc admin. */
    @GetMapping("/orders/{orderCode}")
    public ResponseEntity<ApiResponse<SubscriptionOrderResponse>> getOrder(@PathVariable String orderCode) {
        return ResponseEntity.ok(ApiResponse.success(paymentService.getMyOrder(CurrentUser.requireId(), orderCode)));
    }

    @GetMapping("/orders")
    public ResponseEntity<ApiResponse<PageResponse<SubscriptionOrderResponse>>> getMyOrders(
            @PageableDefault(size = 15, sort = "createdAt", direction = Sort.Direction.DESC) Pageable pageable) {
        return ResponseEntity.ok(ApiResponse.success(paymentService.getMyOrders(CurrentUser.requireId(), pageable)));
    }

    @GetMapping("/my-subscription")
    public ResponseEntity<ApiResponse<SubscriptionStatusResponse>> getMySubscription() {
        return ResponseEntity.ok(ApiResponse.success(subscriptionService.getMySubscription(CurrentUser.requireId())));
    }

    @GetMapping({"/my-quota", "/token-quota"})
    public ResponseEntity<ApiResponse<TokenQuotaResponse>> getTokenQuota() {
        return ResponseEntity.ok(ApiResponse.success(subscriptionService.checkTokenQuota(CurrentUser.requireId())));
    }
}
