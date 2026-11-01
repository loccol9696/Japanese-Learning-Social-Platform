package com.jlsp.backend.subscription.service;

import com.jlsp.backend.subscription.dto.request.SubscriptionPlanRequest;
import com.jlsp.backend.subscription.dto.response.SubscriptionPlanResponse;
import com.jlsp.backend.subscription.dto.response.SubscriptionStatusResponse;
import com.jlsp.backend.subscription.dto.response.TokenQuotaResponse;

import java.util.List;

public interface SubscriptionService {

    List<SubscriptionPlanResponse> getAllActivePlans();

    List<SubscriptionPlanResponse> getAllPlansAdmin();

    SubscriptionPlanResponse getPlanById(Long id);

    SubscriptionPlanResponse createPlan(SubscriptionPlanRequest request);

    SubscriptionPlanResponse updatePlan(Long id, SubscriptionPlanRequest request);

    void deletePlan(Long id);

    TokenQuotaResponse checkTokenQuota(Long userId);

    /** Gói hiện tại của người dùng kèm hạn mức token trong ngày. */
    SubscriptionStatusResponse getMySubscription(Long userId);

    void validateAndDeductTokens(Long userId, int tokensRequired);
}
