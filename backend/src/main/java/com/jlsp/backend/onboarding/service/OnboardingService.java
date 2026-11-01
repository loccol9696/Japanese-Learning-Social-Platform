package com.jlsp.backend.onboarding.service;

import com.jlsp.backend.onboarding.dto.request.OnboardingRequest;
import com.jlsp.backend.onboarding.dto.response.OnboardingStatusResponse;

public interface OnboardingService {

    OnboardingStatusResponse getStatus(Long userId);

    /** Lưu trình độ và sở thích, đánh dấu đã hoàn thành. Chỉ tác động đến người đang đăng nhập. */
    OnboardingStatusResponse save(Long userId, OnboardingRequest request);

    /** Bỏ qua câu hỏi (tăng số lần bỏ qua, tối đa theo OnboardingRules.MAX_SKIPS). */
    OnboardingStatusResponse skip(Long userId);
}
