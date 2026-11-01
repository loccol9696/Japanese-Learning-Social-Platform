package com.jlsp.backend.subscription.service;

import com.jlsp.backend.subscription.dto.request.SubscriptionPlanRequest;
import com.jlsp.backend.subscription.dto.response.SubscriptionPlanResponse;
import com.jlsp.backend.subscription.dto.response.SubscriptionStatusResponse;
import com.jlsp.backend.subscription.dto.response.TokenQuotaResponse;
import com.jlsp.backend.subscription.dto.response.TokenUsageResponse;
import com.jlsp.backend.subscription.entity.TokenFeature;

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

    /**
     * Kiểm hạn mức trong ngày rồi trừ token; vượt hạn mức thì ném lỗi 403 và không trừ gì. Mỗi lần trừ thành công
     * được ghi lại kèm [feature] để thống kê theo tính năng.
     */
    void validateAndDeductTokens(Long userId, int tokensRequired, TokenFeature feature);

    /**
     * Token đã dùng của người dùng theo từng ngày và từng tính năng, trong tuần này (thứ hai đến chủ nhật) hoặc
     * tháng này.
     *
     * @param range "week" hoặc "month"; giá trị khác bị từ chối (400)
     */
    TokenUsageResponse getTokenUsage(Long userId, String range);
}
