package com.jlsp.backend.subscription.controller;

import com.jlsp.backend.common.response.ApiResponse;
import com.jlsp.backend.common.response.PageResponse;
import com.jlsp.backend.common.security.CurrentUser;
import com.jlsp.backend.subscription.dto.request.AdminConfirmRequest;
import com.jlsp.backend.subscription.dto.response.SubscriptionOrderResponse;
import com.jlsp.backend.subscription.entity.SubscriptionOrder;
import com.jlsp.backend.subscription.service.PaymentService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

/** Quản trị thanh toán. Nằm dưới /api/v1/admin nên {@code SecurityConfig} chỉ cho ADMIN. */
@RestController
@RequestMapping("/api/v1/admin/payments")
@RequiredArgsConstructor
public class AdminPaymentController {

    private final PaymentService paymentService;

    @GetMapping
    public ResponseEntity<ApiResponse<PageResponse<SubscriptionOrderResponse>>> getOrders(
            @RequestParam(value = "status", required = false) SubscriptionOrder.OrderStatus status,
            @PageableDefault(size = 15, sort = "createdAt", direction = Sort.Direction.DESC) Pageable pageable) {
        return ResponseEntity.ok(ApiResponse.success(paymentService.getAllOrders(status, pageable)));
    }

    /** Duyệt tay một đơn chưa thành công (vd. khách chuyển thiếu rồi bù tiền mặt); bắt buộc ghi lý do. */
    @PostMapping("/{orderCode}/confirm")
    public ResponseEntity<ApiResponse<SubscriptionOrderResponse>> confirm(
            @PathVariable String orderCode, @Valid @RequestBody AdminConfirmRequest request) {
        SubscriptionOrderResponse response =
                paymentService.adminConfirm(orderCode, CurrentUser.requireId(), request.getNote());
        return ResponseEntity.ok(ApiResponse.success(200, "Đã duyệt đơn " + orderCode, response));
    }
}
