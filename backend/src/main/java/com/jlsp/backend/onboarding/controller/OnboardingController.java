package com.jlsp.backend.onboarding.controller;

import com.jlsp.backend.common.response.ApiResponse;
import com.jlsp.backend.common.security.CurrentUser;
import com.jlsp.backend.onboarding.dto.request.OnboardingRequest;
import com.jlsp.backend.onboarding.dto.response.OnboardingStatusResponse;
import com.jlsp.backend.onboarding.service.OnboardingService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

/** Câu hỏi chào mừng. Mọi endpoint cần đăng nhập; danh tính lấy từ access token. */
@RestController
@RequestMapping("/api/v1/onboarding")
@RequiredArgsConstructor
public class OnboardingController {

    private final OnboardingService onboardingService;

    @GetMapping
    public ApiResponse<OnboardingStatusResponse> getStatus() {
        return ApiResponse.success(onboardingService.getStatus(CurrentUser.requireId()));
    }

    @PutMapping
    public ApiResponse<OnboardingStatusResponse> save(@Valid @RequestBody OnboardingRequest request) {
        return ApiResponse.success(onboardingService.save(CurrentUser.requireId(), request));
    }

    @PostMapping("/skip")
    public ApiResponse<OnboardingStatusResponse> skip() {
        return ApiResponse.success(onboardingService.skip(CurrentUser.requireId()));
    }
}
