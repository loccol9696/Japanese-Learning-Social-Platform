package com.jlsp.backend.subscription.service;

import com.jlsp.backend.common.response.PageResponse;
import com.jlsp.backend.subscription.dto.request.ConfirmPaymentRequest;
import com.jlsp.backend.subscription.dto.request.CreateQrOrderRequest;
import com.jlsp.backend.subscription.dto.request.SubscriptionPlanRequest;
import com.jlsp.backend.subscription.dto.response.SubscriptionOrderResponse;
import com.jlsp.backend.subscription.dto.response.SubscriptionPlanResponse;
import com.jlsp.backend.subscription.dto.response.TokenQuotaResponse;
import com.jlsp.backend.subscription.entity.SubscriptionOrder;
import org.springframework.data.domain.Pageable;

import java.util.List;
import java.util.Map;

public interface SubscriptionService {

    List<SubscriptionPlanResponse> getAllActivePlans();

    List<SubscriptionPlanResponse> getAllPlansAdmin();

    SubscriptionPlanResponse getPlanById(Long id);

    SubscriptionPlanResponse createPlan(SubscriptionPlanRequest request);

    SubscriptionPlanResponse updatePlan(Long id, SubscriptionPlanRequest request);

    void deletePlan(Long id);

    SubscriptionOrderResponse createQrOrder(CreateQrOrderRequest request);

    SubscriptionOrderResponse confirmPayment(ConfirmPaymentRequest request);

    SubscriptionOrderResponse getOrderStatus(String orderCode);

    PageResponse<SubscriptionOrderResponse> getSubscriptionHistory(SubscriptionOrder.OrderStatus status, Pageable pageable);

    TokenQuotaResponse checkTokenQuota(Long userId);

    void validateAndDeductTokens(Long userId, int tokensRequired);

    Map<String, Object> getUserSubscriptionStatus(Long userId);

    Map<String, Object> saveSepayApiToken(String apiToken);

    Map<String, Object> getSepayTokenStatus();
}
