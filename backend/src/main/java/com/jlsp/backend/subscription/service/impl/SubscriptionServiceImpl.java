package com.jlsp.backend.subscription.service.impl;

import com.jlsp.backend.common.exception.AppException;
import com.jlsp.backend.common.exception.ResourceNotFoundException;
import com.jlsp.backend.common.response.PageResponse;
import com.jlsp.backend.subscription.dto.request.ConfirmPaymentRequest;
import com.jlsp.backend.subscription.dto.request.CreateQrOrderRequest;
import com.jlsp.backend.subscription.dto.request.SubscriptionPlanRequest;
import com.jlsp.backend.subscription.dto.response.SubscriptionOrderResponse;
import com.jlsp.backend.subscription.dto.response.SubscriptionPlanResponse;
import com.jlsp.backend.subscription.dto.response.TokenQuotaResponse;
import com.jlsp.backend.subscription.entity.SubscriptionOrder;
import com.jlsp.backend.subscription.entity.SubscriptionPlan;
import com.jlsp.backend.subscription.entity.UserDailyTokenUsage;
import com.jlsp.backend.subscription.repository.SubscriptionOrderRepository;
import com.jlsp.backend.subscription.repository.SubscriptionPlanRepository;
import com.jlsp.backend.subscription.repository.UserDailyTokenUsageRepository;
import com.jlsp.backend.subscription.service.SubscriptionService;
import com.jlsp.backend.user.entity.User;
import com.jlsp.backend.user.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
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
    private final SubscriptionOrderRepository orderRepository;
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
    @Transactional
    public SubscriptionOrderResponse createQrOrder(CreateQrOrderRequest request) {
        SubscriptionPlan plan = null;
        if (request.getPlanId() != null) {
            plan = planRepository.findById(request.getPlanId()).orElse(null);
        }
        if (plan == null && request.getPlanCode() != null && !request.getPlanCode().isBlank()) {
            plan = planRepository.findByCode(request.getPlanCode().trim().toUpperCase()).orElse(null);
        }
        if (plan == null) {
            plan = planRepository.findAll().stream().findFirst()
                    .orElseThrow(() -> new AppException(404, "Không tìm thấy gói thành viên tương ứng"));
        }

        if (request.getUserId() == null) {
            throw new AppException(401, "Vui lòng đăng nhập để tiếp tục");
        }
        User user = userRepository.findById(request.getUserId())
                .orElseThrow(() -> new AppException(404, "Không tìm thấy tài khoản"));

        long timestamp = System.currentTimeMillis();
        String orderCode = "TX-" + (timestamp % 1000000);
        String verificationCode = "JLSP-" + (int)(Math.random() * 90000 + 10000);

        // QR image link using VietQR standard quick-link format / QR Server
        String qrContent = String.format("JLSP_PAYMENT_%s_%s", orderCode, verificationCode);
        String qrUrl = "https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=" + qrContent;

        SubscriptionOrder order = SubscriptionOrder.builder()
                .orderCode(orderCode)
                .verificationCode(verificationCode)
                .user(user)
                .plan(plan)
                .amount(plan.getPrice())
                .paymentMethod("VIETQR_LOCAL")
                .status(SubscriptionOrder.OrderStatus.PENDING)
                .qrUrl(qrUrl)
                .build();

        SubscriptionOrder saved = orderRepository.save(order);
        log.info("Created QR Payment Order {} for user {} with verificationCode {}", orderCode, user.getUsername(), verificationCode);
        return toOrderResponse(saved);
    }

    @Override
    @Transactional
    public SubscriptionOrderResponse confirmPayment(ConfirmPaymentRequest request) {
        String code = request.getVerificationCode() != null ? request.getVerificationCode().trim().toUpperCase() : "";
        SubscriptionOrder order = null;
        if (!code.isBlank()) {
            order = orderRepository.findByVerificationCode(code).orElse(null);
        }
        if (order == null && request.getOrderCode() != null && !request.getOrderCode().isBlank()) {
            order = orderRepository.findByOrderCode(request.getOrderCode().trim()).orElse(null);
        }
        if (order == null) {
            throw new AppException(400, "Mã xác nhận dưới QR không hợp lệ hoặc không tồn tại: " + code);
        }

        if (order.getStatus() == SubscriptionOrder.OrderStatus.SUCCESS) {
            return toOrderResponse(order);
        }

        order.setStatus(SubscriptionOrder.OrderStatus.SUCCESS);
        order.setCompletedAt(LocalDateTime.now());
        orderRepository.save(order);

        // Kích hoạt VIP cho User
        User user = order.getUser();
        user.setSubscriptionPlan(order.getPlan());
        LocalDateTime currentExpire = user.getVipExpiresAt();
        LocalDateTime baseTime = (currentExpire != null && currentExpire.isAfter(LocalDateTime.now())) ? currentExpire : LocalDateTime.now();
        user.setVipExpiresAt(baseTime.plusDays(order.getPlan().getDurationDays()));
        userRepository.save(user);

        log.info("Payment CONFIRMED for order {} via code {}. User {} upgraded to plan {} with limit {} tokens/day!",
                order.getOrderCode(), code, user.getUsername(), order.getPlan().getName(), order.getPlan().getDailyTokenLimit());

        return toOrderResponse(order);
    }

    @Override
    @Transactional
    public SubscriptionOrderResponse processBankWebhook(com.jlsp.backend.subscription.dto.request.BankWebhookRequest request) {
        if (request == null) {
            throw new AppException(400, "Dữ liệu webhook không hợp lệ");
        }

        String searchTarget = "";
        if (request.getContent() != null) searchTarget += " " + request.getContent();
        if (request.getDescription() != null) searchTarget += " " + request.getDescription();
        if (request.getVerificationCode() != null) searchTarget += " " + request.getVerificationCode();
        if (request.getOrderCode() != null) searchTarget += " " + request.getOrderCode();
        searchTarget = searchTarget.toUpperCase();

        SubscriptionOrder order = null;

        // 1. Tìm theo verificationCode trực tiếp hoặc regex JLSP-\d+
        if (request.getVerificationCode() != null && !request.getVerificationCode().isBlank()) {
            order = orderRepository.findByVerificationCode(request.getVerificationCode().trim().toUpperCase()).orElse(null);
        }

        if (order == null) {
            java.util.regex.Pattern pVerify = java.util.regex.Pattern.compile("JLSP-\\d+");
            java.util.regex.Matcher mVerify = pVerify.matcher(searchTarget);
            if (mVerify.find()) {
                String extractedCode = mVerify.group();
                order = orderRepository.findByVerificationCode(extractedCode).orElse(null);
            }
        }

        // 2. Tìm theo orderCode trực tiếp hoặc regex TX-\d+
        if (order == null && request.getOrderCode() != null && !request.getOrderCode().isBlank()) {
            order = orderRepository.findByOrderCode(request.getOrderCode().trim()).orElse(null);
        }

        if (order == null) {
            java.util.regex.Pattern pOrder = java.util.regex.Pattern.compile("TX-\\d+");
            java.util.regex.Matcher mOrder = pOrder.matcher(searchTarget);
            if (mOrder.find()) {
                String extractedOrder = mOrder.group();
                order = orderRepository.findByOrderCode(extractedOrder).orElse(null);
            }
        }

        if (order == null) {
            log.warn("Webhook received but no matching order found for content: '{}'", searchTarget);
            throw new AppException(404, "Không tìm thấy đơn hàng tương ứng với nội dung chuyển khoản ngân hàng: " + searchTarget);
        }

        if (order.getStatus() == SubscriptionOrder.OrderStatus.SUCCESS) {
            log.info("Order {} is already SUCCESS, skipping duplicate webhook", order.getOrderCode());
            return toOrderResponse(order);
        }

        order.setStatus(SubscriptionOrder.OrderStatus.SUCCESS);
        order.setCompletedAt(LocalDateTime.now());
        if (request.getGateway() != null && !request.getGateway().isBlank()) {
            order.setPaymentMethod(request.getGateway().trim());
        }
        orderRepository.save(order);

        // Kích hoạt VIP cho User
        User user = order.getUser();
        user.setSubscriptionPlan(order.getPlan());
        LocalDateTime currentExpire = user.getVipExpiresAt();
        LocalDateTime baseTime = (currentExpire != null && currentExpire.isAfter(LocalDateTime.now())) ? currentExpire : LocalDateTime.now();
        user.setVipExpiresAt(baseTime.plusDays(order.getPlan().getDurationDays()));
        userRepository.save(user);

        log.info("AUTOMATIC PAYMENT SUCCESS: Order {} confirmed via Webhook. User {} upgraded to VIP plan {} until {}",
                order.getOrderCode(), user.getUsername(), order.getPlan().getName(), user.getVipExpiresAt());

        return toOrderResponse(order);
    }

    @Override
    public SubscriptionOrderResponse getOrderStatus(String orderCode) {
        SubscriptionOrder order = orderRepository.findByOrderCode(orderCode)
                .orElseThrow(() -> new ResourceNotFoundException("SubscriptionOrder", "orderCode", orderCode));
        return toOrderResponse(order);
    }

    @Override
    public PageResponse<SubscriptionOrderResponse> getSubscriptionHistory(SubscriptionOrder.OrderStatus status, Pageable pageable) {
        Page<SubscriptionOrder> page = (status != null)
                ? orderRepository.findByStatus(status, pageable)
                : orderRepository.findAll(pageable);

        List<SubscriptionOrderResponse> responses = page.getContent().stream()
                .map(this::toOrderResponse)
                .collect(Collectors.toList());

        return PageResponse.<SubscriptionOrderResponse>builder()
                .content(responses)
                .page(page.getNumber())
                .size(page.getSize())
                .totalElements(page.getTotalElements())
                .totalPages(page.getTotalPages())
                .last(page.isLast())
                .build();
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

    private SubscriptionOrderResponse toOrderResponse(SubscriptionOrder order) {
        User user = order.getUser();
        SubscriptionPlan plan = order.getPlan();

        return SubscriptionOrderResponse.builder()
                .id(order.getId())
                .orderCode(order.getOrderCode())
                .verificationCode(order.getVerificationCode())
                .userId(user != null ? user.getId() : null)
                .username(user != null ? user.getUsername() : null)
                .userEmail(user != null ? user.getEmail() : null)
                .planId(plan != null ? plan.getId() : null)
                .planName(plan != null ? plan.getName() : null)
                .dailyTokenLimit(plan != null ? plan.getDailyTokenLimit() : 50)
                .amount(order.getAmount())
                .paymentMethod(order.getPaymentMethod())
                .status(order.getStatus())
                .qrUrl(order.getQrUrl())
                .paymentWebUrl("/payment-confirm?code=" + order.getVerificationCode())
                .createdAt(order.getCreatedAt())
                .completedAt(order.getCompletedAt())
                .build();
    }
}
