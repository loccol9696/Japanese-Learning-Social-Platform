package com.jlsp.backend.subscription.service.impl;

import com.jlsp.backend.common.exception.AppException;
import com.jlsp.backend.common.exception.ResourceNotFoundException;
import com.jlsp.backend.subscription.dto.request.SubscriptionPlanRequest;
import com.jlsp.backend.subscription.dto.response.SubscriptionPlanResponse;
import com.jlsp.backend.subscription.dto.response.SubscriptionStatusResponse;
import com.jlsp.backend.subscription.dto.response.TokenQuotaResponse;
import com.jlsp.backend.subscription.entity.SubscriptionPlan;
import com.jlsp.backend.subscription.entity.UserDailyTokenUsage;
import com.jlsp.backend.subscription.repository.SubscriptionPlanRepository;
import com.jlsp.backend.subscription.repository.UserDailyTokenUsageRepository;
import com.jlsp.backend.subscription.service.SubscriptionService;
import com.jlsp.backend.user.entity.User;
import com.jlsp.backend.user.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.stream.Collectors;

@Service
@Transactional
@RequiredArgsConstructor
@Slf4j
public class SubscriptionServiceImpl implements SubscriptionService {

    private final SubscriptionPlanRepository planRepository;
    private final UserDailyTokenUsageRepository tokenUsageRepository;
    private final UserRepository userRepository;

    @Override
    public List<SubscriptionPlanResponse> getAllActivePlans() {
        return planRepository.findByIsActiveTrueOrderByPriceAsc().stream()
                .map(this::toPlanResponse)
                .collect(Collectors.toList());
    }

    @Override
    public List<SubscriptionPlanResponse> getAllPlansAdmin() {
        return planRepository.findAll().stream()
                .map(this::toPlanResponse)
                .collect(Collectors.toList());
    }

    @Override
    public SubscriptionPlanResponse getPlanById(Long id) {
        SubscriptionPlan plan = planRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("SubscriptionPlan", "id", id));
        return toPlanResponse(plan);
    }

    @Override
    @Transactional
    public SubscriptionPlanResponse createPlan(SubscriptionPlanRequest request) {
        String code = request.getCode() != null && !request.getCode().isBlank()
                ? request.getCode().trim().toUpperCase()
                : "PLAN_" + System.currentTimeMillis();

        SubscriptionPlan plan = SubscriptionPlan.builder()
                .name(request.getName())
                .code(code)
                .price(request.getPrice())
                .durationDays(request.getDurationDays())
                .dailyTokenLimit(request.getDailyTokenLimit())
                .description(request.getDescription())
                .features(request.getFeatures())
                .isActive(request.getIsActive() != null ? request.getIsActive() : true)
                .build();

        SubscriptionPlan saved = planRepository.save(plan);
        log.info("Admin created new subscription plan '{}' with dailyTokenLimit={}", saved.getName(), saved.getDailyTokenLimit());
        return toPlanResponse(saved);
    }

    @Override
    @Transactional
    public SubscriptionPlanResponse updatePlan(Long id, SubscriptionPlanRequest request) {
        SubscriptionPlan plan = planRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("SubscriptionPlan", "id", id));

        if (request.getName() != null && !request.getName().isBlank()) {
            plan.setName(request.getName());
        }
        if (request.getPrice() != null) {
            plan.setPrice(request.getPrice());
        }
        if (request.getDurationDays() != null) {
            plan.setDurationDays(request.getDurationDays());
        }
        if (request.getDailyTokenLimit() != null) {
            plan.setDailyTokenLimit(request.getDailyTokenLimit());
        }
        if (request.getDescription() != null) {
            plan.setDescription(request.getDescription());
        }
        if (request.getFeatures() != null) {
            plan.setFeatures(request.getFeatures());
        }
        if (request.getIsActive() != null) {
            plan.setIsActive(request.getIsActive());
        }

        SubscriptionPlan updated = planRepository.save(plan);
        log.info("Admin updated plan ID={} '{}': price={}, dailyTokenLimit={}", id, updated.getName(), updated.getPrice(), updated.getDailyTokenLimit());
        return toPlanResponse(updated);
    }

    @Override
    @Transactional
    public void deletePlan(Long id) {
        SubscriptionPlan plan = planRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("SubscriptionPlan", "id", id));
        plan.setIsActive(false);
        planRepository.save(plan);
        log.info("Admin deactivated plan ID={}", id);
    }

    @Override
    public TokenQuotaResponse checkTokenQuota(Long userId) {
        User user = userRepository.findById(userId).orElse(null);

        // Truy vấn động gói FREE từ database làm chuẩn
        SubscriptionPlan freePlan = planRepository.findByCode("FREE").orElse(null);
        int freeLimit = (freePlan != null && freePlan.getDailyTokenLimit() != null)
                ? freePlan.getDailyTokenLimit()
                : 50;
        String freePlanName = (freePlan != null && freePlan.getName() != null)
                ? freePlan.getName()
                : "Miễn phí (Free)";

        // Kiểm tra xem người dùng có gói VIP còn hạn hay không
        boolean hasActiveVip = user != null && user.getSubscriptionPlan() != null
                && (user.getVipExpiresAt() == null || user.getVipExpiresAt().isAfter(LocalDateTime.now()));

        SubscriptionPlan activePlan = hasActiveVip ? user.getSubscriptionPlan() : freePlan;

        int limit = (activePlan != null && activePlan.getDailyTokenLimit() != null)
                ? activePlan.getDailyTokenLimit()
                : freeLimit;
        String planName = (activePlan != null && activePlan.getName() != null)
                ? activePlan.getName()
                : freePlanName;

        LocalDate today = LocalDate.now();
        int used = 0;
        if (user != null) {
            used = tokenUsageRepository.findByUserIdAndUsageDate(userId, today)
                    .map(UserDailyTokenUsage::getTokensUsed)
                    .orElse(0);
        }

        return TokenQuotaResponse.builder()
                .userId(userId)
                .planName(planName)
                .dailyTokenLimit(limit)
                .tokensUsedToday(used)
                .tokensRemainingToday(Math.max(0, limit - used))
                .build();
    }

    @Override
    public SubscriptionStatusResponse getMySubscription(Long userId) {
        User user = userRepository.findById(userId).orElse(null);
        TokenQuotaResponse quota = checkTokenQuota(userId);

        LocalDateTime now = LocalDateTime.now();
        SubscriptionPlan plan = user != null ? user.getSubscriptionPlan() : null;
        boolean paidPlan = plan != null && plan.getPrice() != null && plan.getPrice().signum() > 0;
        LocalDateTime expiresAt = user != null ? user.getVipExpiresAt() : null;
        boolean active = paidPlan && (expiresAt == null || expiresAt.isAfter(now));
        boolean lifetime = active && expiresAt == null;
        int remainingDays = 0;
        if (active && expiresAt != null) {
            remainingDays = (int) Math.max(0, java.time.temporal.ChronoUnit.DAYS.between(now, expiresAt));
        }

        return SubscriptionStatusResponse.builder()
                .vip(active)
                .planId(active ? plan.getId() : null)
                .planCode(active ? plan.getCode() : null)
                .planName(quota.getPlanName())
                .expiresAt(active ? expiresAt : null)
                .lifetime(lifetime)
                .remainingDays(remainingDays)
                .dailyTokenLimit(quota.getDailyTokenLimit())
                .tokensUsedToday(quota.getTokensUsedToday())
                .tokensRemainingToday(quota.getTokensRemainingToday())
                .build();
    }

    @Override
    @Transactional
    public void validateAndDeductTokens(Long userId, int tokensRequired) {
        User user = userRepository.findById(userId).orElse(null);

        // Truy vấn động gói FREE từ database làm chuẩn
        SubscriptionPlan freePlan = planRepository.findByCode("FREE").orElse(null);
        int freeLimit = (freePlan != null && freePlan.getDailyTokenLimit() != null)
                ? freePlan.getDailyTokenLimit()
                : 50;

        // Kiểm tra xem người dùng có gói VIP còn hạn hay không
        boolean hasActiveVip = user != null && user.getSubscriptionPlan() != null
                && (user.getVipExpiresAt() == null || user.getVipExpiresAt().isAfter(LocalDateTime.now()));

        SubscriptionPlan activePlan = hasActiveVip ? user.getSubscriptionPlan() : freePlan;

        int limit = (activePlan != null && activePlan.getDailyTokenLimit() != null)
                ? activePlan.getDailyTokenLimit()
                : freeLimit;

        LocalDate today = LocalDate.now();
        UserDailyTokenUsage usage = (user != null)
                ? tokenUsageRepository.findByUserIdAndUsageDate(userId, today)
                    .orElseGet(() -> UserDailyTokenUsage.builder()
                            .user(user)
                            .usageDate(today)
                            .tokensUsed(0)
                            .build())
                : null;

        int currentUsed = usage != null ? usage.getTokensUsed() : 0;

        if (currentUsed + tokensRequired > limit) {
            throw new AppException(403, String.format(
                    "Bạn đã dùng %d/%d token AI hôm nay. Yêu cầu cần thêm %d token vượt quá giới hạn ngày! Vui lòng nâng cấp VIP hoặc chờ sang ngày mới.",
                    currentUsed, limit, tokensRequired));
        }

        if (usage != null) {
            usage.setTokensUsed(currentUsed + tokensRequired);
            tokenUsageRepository.save(usage);
            log.info("Deducted {} tokens from user ID {}. New usage today: {}/{} tokens",
                    tokensRequired, userId, usage.getTokensUsed(), limit);
        }
    }

    private SubscriptionPlanResponse toPlanResponse(SubscriptionPlan plan) {
        return SubscriptionPlanResponse.builder()
                .id(plan.getId())
                .name(plan.getName())
                .code(plan.getCode())
                .price(plan.getPrice())
                .durationDays(plan.getDurationDays())
                .dailyTokenLimit(plan.getDailyTokenLimit())
                .description(plan.getDescription())
                .features(plan.getFeatures())
                .isActive(plan.getIsActive())
                .createdAt(plan.getCreatedAt())
                .updatedAt(plan.getUpdatedAt())
                .build();
    }
}
