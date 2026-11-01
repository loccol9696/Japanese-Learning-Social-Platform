package com.jlsp.backend.subscription.service.impl;

import com.jlsp.backend.common.exception.AppException;
import com.jlsp.backend.common.exception.ResourceNotFoundException;
import com.jlsp.backend.subscription.dto.request.PromoCodeRequest;
import com.jlsp.backend.subscription.dto.request.SubscriptionPlanRequest;
import com.jlsp.backend.subscription.dto.response.PromoCodeResponse;
import com.jlsp.backend.subscription.dto.response.SubscriptionPlanResponse;
import com.jlsp.backend.subscription.dto.response.SubscriptionStatusResponse;
import com.jlsp.backend.subscription.dto.response.TokenQuotaResponse;
import com.jlsp.backend.subscription.entity.PromoCode;
import com.jlsp.backend.subscription.entity.SubscriptionPlan;
import com.jlsp.backend.subscription.entity.UserDailyTokenUsage;
import com.jlsp.backend.subscription.repository.PromoCodeRepository;
import com.jlsp.backend.subscription.repository.SubscriptionPlanRepository;
import com.jlsp.backend.subscription.repository.UserDailyTokenUsageRepository;
import com.jlsp.backend.subscription.service.SubscriptionService;
import com.jlsp.backend.user.entity.User;
import com.jlsp.backend.user.entity.UserRole;
import com.jlsp.backend.user.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
@Transactional
@RequiredArgsConstructor
@Slf4j
public class SubscriptionServiceImpl implements SubscriptionService {

    private final SubscriptionPlanRepository planRepository;
    private final UserDailyTokenUsageRepository tokenUsageRepository;
    private final UserRepository userRepository;
    private final PromoCodeRepository promoCodeRepository;

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

        // Admin luôn có đặc quyền tối cao vô hạn token
        if (user != null && user.getRole() == UserRole.ADMIN) {
            return TokenQuotaResponse.builder()
                    .userId(userId)
                    .planName("Đặc quyền Quản trị viên (Admin)")
                    .dailyTokenLimit(999999)
                    .tokensUsedToday(0)
                    .tokensRemainingToday(999999)
                    .build();
        }

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

        if (user != null && user.getRole() == UserRole.ADMIN) {
            return SubscriptionStatusResponse.builder()
                    .vip(true)
                    .planId(999L)
                    .planCode("ADMIN_UNLIMITED")
                    .planName("Đặc quyền Quản trị viên (Admin)")
                    .expiresAt(null)
                    .lifetime(true)
                    .remainingDays(9999)
                    .dailyTokenLimit(999999)
                    .tokensUsedToday(0)
                    .tokensRemainingToday(999999)
                    .build();
        }

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

        // Admin luôn có quyền vô hạn token
        if (user != null && user.getRole() == UserRole.ADMIN) {
            log.info("User ID {} is ADMIN. Unlimited tokens granted, skipping deduction quota check.", userId);
            return;
        }

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

    // ==================== PROMO CODE / VOUCHER ====================

    @Override
    public List<PromoCodeResponse> getAllPromoCodes() {
        return promoCodeRepository.findAllByOrderByCreatedAtDesc().stream()
                .map(this::toPromoCodeResponse)
                .collect(Collectors.toList());
    }

    @Override
    @Transactional
    public PromoCodeResponse createPromoCode(PromoCodeRequest request) {
        String code = request.getCode() != null ? request.getCode().trim().toUpperCase() : "";
        if (code.isEmpty()) {
            throw new AppException(400, "Mã khuyến mãi không được để trống");
        }
        if (promoCodeRepository.existsByCodeIgnoreCase(code)) {
            throw new AppException(400, "Mã khuyến mãi '" + code + "' đã tồn tại trong hệ thống");
        }

        PromoCode promo = PromoCode.builder()
                .code(code)
                .description(request.getDescription())
                .discountPercent(request.getDiscountPercent() != null ? request.getDiscountPercent() : 0)
                .discountAmount(request.getDiscountAmount() != null ? request.getDiscountAmount() : BigDecimal.ZERO)
                .minOrderAmount(request.getMinOrderAmount() != null ? request.getMinOrderAmount() : BigDecimal.ZERO)
                .maxUses(request.getMaxUses() != null ? request.getMaxUses() : 100)
                .usedCount(0)
                .startDate(request.getStartDate() != null ? request.getStartDate() : LocalDateTime.now())
                .endDate(request.getEndDate())
                .isActive(request.getIsActive() != null ? request.getIsActive() : true)
                .build();

        PromoCode saved = promoCodeRepository.save(promo);
        log.info("Admin created new promo code: {}", saved.getCode());
        return toPromoCodeResponse(saved);
    }

    @Override
    @Transactional
    public PromoCodeResponse updatePromoCode(Long id, PromoCodeRequest request) {
        PromoCode promo = promoCodeRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("PromoCode", "id", id));

        if (request.getDescription() != null) promo.setDescription(request.getDescription());
        if (request.getDiscountPercent() != null) promo.setDiscountPercent(request.getDiscountPercent());
        if (request.getDiscountAmount() != null) promo.setDiscountAmount(request.getDiscountAmount());
        if (request.getMinOrderAmount() != null) promo.setMinOrderAmount(request.getMinOrderAmount());
        if (request.getMaxUses() != null) promo.setMaxUses(request.getMaxUses());
        if (request.getStartDate() != null) promo.setStartDate(request.getStartDate());
        if (request.getEndDate() != null) promo.setEndDate(request.getEndDate());
        if (request.getIsActive() != null) promo.setIsActive(request.getIsActive());

        PromoCode updated = promoCodeRepository.save(promo);
        return toPromoCodeResponse(updated);
    }

    @Override
    @Transactional
    public PromoCodeResponse togglePromoCodeStatus(Long id) {
        PromoCode promo = promoCodeRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("PromoCode", "id", id));
        promo.setIsActive(!Boolean.TRUE.equals(promo.getIsActive()));
        PromoCode updated = promoCodeRepository.save(promo);
        return toPromoCodeResponse(updated);
    }

    @Override
    @Transactional
    public void deletePromoCode(Long id) {
        PromoCode promo = promoCodeRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("PromoCode", "id", id));
        promoCodeRepository.delete(promo);
    }

    @Override
    public Map<String, Object> verifyPromoCode(String rawCode, Long planId) {
        if (rawCode == null || rawCode.trim().isEmpty()) {
            throw new AppException(400, "Vui lòng nhập mã khuyến mãi");
        }
        String code = rawCode.trim().toUpperCase();
        Map<String, Object> res = new HashMap<>();
        res.put("code", code);

        PromoCode promo = promoCodeRepository.findByCodeIgnoreCase(code).orElse(null);
        if (promo != null) {
            if (!Boolean.TRUE.equals(promo.getIsActive())) {
                throw new AppException(400, "Mã khuyến mãi '" + code + "' hiện đang tạm khóa hoặc đã bị vô hiệu hóa.");
            }
            LocalDateTime now = LocalDateTime.now();
            if (promo.getStartDate() != null && now.isBefore(promo.getStartDate())) {
                throw new AppException(400, "Mã khuyến mãi '" + code + "' chưa đến thời gian áp dụng.");
            }
            if (promo.getEndDate() != null && now.isAfter(promo.getEndDate())) {
                throw new AppException(400, "Mã khuyến mãi '" + code + "' đã hết hạn sử dụng.");
            }
            if (promo.getMaxUses() != null && promo.getUsedCount() != null && promo.getUsedCount() >= promo.getMaxUses()) {
                throw new AppException(400, "Mã khuyến mãi '" + code + "' đã đạt giới hạn số lượt sử dụng.");
            }

            int percent = promo.getDiscountPercent() != null ? promo.getDiscountPercent() : 0;
            BigDecimal amount = promo.getDiscountAmount() != null ? promo.getDiscountAmount() : BigDecimal.ZERO;

            res.put("valid", true);
            res.put("discountPercent", percent);
            res.put("discountAmount", amount);
            res.put("description", promo.getDescription() != null ? promo.getDescription() : "Giảm giá đặc biệt");
            return res;
        }

        throw new AppException(400, "Mã khuyến mãi '" + code + "' không tồn tại trong hệ thống.");
    }

    private PromoCodeResponse toPromoCodeResponse(PromoCode p) {
        return PromoCodeResponse.builder()
                .id(p.getId())
                .code(p.getCode())
                .description(p.getDescription())
                .discountPercent(p.getDiscountPercent())
                .discountAmount(p.getDiscountAmount())
                .minOrderAmount(p.getMinOrderAmount())
                .maxUses(p.getMaxUses())
                .usedCount(p.getUsedCount())
                .startDate(p.getStartDate())
                .endDate(p.getEndDate())
                .isActive(p.getIsActive())
                .createdAt(p.getCreatedAt())
                .updatedAt(p.getUpdatedAt())
                .build();
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
