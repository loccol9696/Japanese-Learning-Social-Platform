package com.jlsp.backend.subscription.controller;

import com.jlsp.backend.common.response.ApiResponse;
import com.jlsp.backend.subscription.dto.request.PromoCodeRequest;
import com.jlsp.backend.subscription.dto.response.PromoCodeResponse;
import com.jlsp.backend.subscription.service.SubscriptionService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping({"/api/v1/admin/promo-codes", "/api/v1/subscriptions/admin/promo-codes"})
@RequiredArgsConstructor
public class AdminPromoCodeController {

    private final SubscriptionService subscriptionService;

    @GetMapping
    public ResponseEntity<ApiResponse<List<PromoCodeResponse>>> getAllPromoCodes() {
        List<PromoCodeResponse> list = subscriptionService.getAllPromoCodes();
        return ResponseEntity.ok(ApiResponse.success(list));
    }

    @PostMapping
    public ResponseEntity<ApiResponse<PromoCodeResponse>> createPromoCode(
            @Valid @RequestBody PromoCodeRequest request) {
        PromoCodeResponse created = subscriptionService.createPromoCode(request);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.success(201, "Tạo mã khuyến mãi thành công", created));
    }

    @PutMapping("/{id}")
    public ResponseEntity<ApiResponse<PromoCodeResponse>> updatePromoCode(
            @PathVariable Long id,
            @Valid @RequestBody PromoCodeRequest request) {
        PromoCodeResponse updated = subscriptionService.updatePromoCode(id, request);
        return ResponseEntity.ok(ApiResponse.success(200, "Cập nhật mã khuyến mãi thành công", updated));
    }

    @PutMapping("/{id}/toggle")
    public ResponseEntity<ApiResponse<PromoCodeResponse>> togglePromoCodeStatus(@PathVariable Long id) {
        PromoCodeResponse toggled = subscriptionService.togglePromoCodeStatus(id);
        String msg = Boolean.TRUE.equals(toggled.getIsActive()) ? "Đã kích hoạt mã khuyến mãi" : "Đã tạm dừng mã khuyến mãi";
        return ResponseEntity.ok(ApiResponse.success(200, msg, toggled));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<ApiResponse<Void>> deletePromoCode(@PathVariable Long id) {
        subscriptionService.deletePromoCode(id);
        return ResponseEntity.ok(ApiResponse.success(200, "Đã xóa mã khuyến mãi thành công", null));
    }
}
