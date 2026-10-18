package com.jlsp.backend.subscription.controller;

import com.jlsp.backend.common.response.ApiResponse;
import com.jlsp.backend.subscription.dto.request.SubscriptionPlanRequest;
import com.jlsp.backend.subscription.dto.request.UpdateTokenRateRequest;
import com.jlsp.backend.subscription.dto.response.SubscriptionPlanResponse;
import com.jlsp.backend.subscription.service.SubscriptionService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/subscription-plans")
@RequiredArgsConstructor
public class SubscriptionPlanController {

    private final SubscriptionService subscriptionService;
    private final com.jlsp.backend.subscription.service.SystemSettingService systemSettingService;

    @GetMapping({"/token-rate", "/admin/token-rate"})
    public ResponseEntity<ApiResponse<com.jlsp.backend.subscription.dto.response.TokenRateDto>> getTokenRate() {
        return ResponseEntity.ok(ApiResponse.success(systemSettingService.getTokenRate()));
    }

    @PutMapping({"/token-rate", "/admin/token-rate"})
    public ResponseEntity<ApiResponse<com.jlsp.backend.subscription.dto.response.TokenRateDto>> updateTokenRate(
            @Valid @RequestBody UpdateTokenRateRequest request) {
        com.jlsp.backend.subscription.dto.response.TokenRateDto updated =
                systemSettingService.setSecondsPerToken(request.getSecondsPerToken());
        return ResponseEntity.ok(ApiResponse.success(200, "Cập nhật cấu hình tỷ lệ quy đổi Token thành công", updated));
    }

    @GetMapping
    public ResponseEntity<ApiResponse<List<SubscriptionPlanResponse>>> getActivePlans() {
        List<SubscriptionPlanResponse> plans = subscriptionService.getAllActivePlans();
        return ResponseEntity.ok(ApiResponse.success(plans));
    }

    @GetMapping({"/admin-all", "/admin/all"})
    public ResponseEntity<ApiResponse<List<SubscriptionPlanResponse>>> getAllPlansAdmin() {
        List<SubscriptionPlanResponse> plans = subscriptionService.getAllPlansAdmin();
        return ResponseEntity.ok(ApiResponse.success(plans));
    }

    @GetMapping("/{id:[0-9]+}")
    public ResponseEntity<ApiResponse<SubscriptionPlanResponse>> getPlanById(@PathVariable Long id) {
        SubscriptionPlanResponse plan = subscriptionService.getPlanById(id);
        return ResponseEntity.ok(ApiResponse.success(plan));
    }

    @PostMapping({"", "/admin"})
    public ResponseEntity<ApiResponse<SubscriptionPlanResponse>> createPlan(
            @Valid @RequestBody SubscriptionPlanRequest request) {
        SubscriptionPlanResponse plan = subscriptionService.createPlan(request);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.success(HttpStatus.CREATED.value(), "Tạo gói thành viên thành công", plan));
    }

    @PutMapping({"/{id:[0-9]+}", "/admin/{id:[0-9]+}"})
    public ResponseEntity<ApiResponse<SubscriptionPlanResponse>> updatePlan(
            @PathVariable Long id,
            @Valid @RequestBody SubscriptionPlanRequest request) {
        SubscriptionPlanResponse plan = subscriptionService.updatePlan(id, request);
        return ResponseEntity.ok(ApiResponse.success(200, "Cập nhật gói thành viên thành công", plan));
    }

    @DeleteMapping("/admin/{id}")
    public ResponseEntity<ApiResponse<Void>> deletePlan(@PathVariable Long id) {
        subscriptionService.deletePlan(id);
        return ResponseEntity.ok(ApiResponse.success(200, "Đã ẩn gói thành công", null));
    }
}
