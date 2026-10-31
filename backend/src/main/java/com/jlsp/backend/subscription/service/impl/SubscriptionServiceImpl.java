package com.jlsp.backend.subscription.service.impl;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
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
import com.jlsp.backend.subscription.entity.SystemSetting;
import com.jlsp.backend.subscription.entity.UserDailyTokenUsage;
import com.jlsp.backend.subscription.repository.SubscriptionOrderRepository;
import com.jlsp.backend.subscription.repository.SubscriptionPlanRepository;
import com.jlsp.backend.subscription.repository.SystemSettingRepository;
import com.jlsp.backend.subscription.repository.UserDailyTokenUsageRepository;
import com.jlsp.backend.subscription.service.SubscriptionService;
import com.jlsp.backend.user.entity.User;
import com.jlsp.backend.user.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.HashMap;
import java.util.stream.Collectors;

@Service
@Transactional
@RequiredArgsConstructor
@Slf4j
public class SubscriptionServiceImpl implements SubscriptionService {

    private static final String SEPAY_TOKEN_SETTING_KEY = "SEPAY_API_TOKEN";
    private static final String SEPAY_TRANSACTIONS_API_URL = "https://my.sepay.vn/userapi/transactions/list?limit=20";

    private final SubscriptionPlanRepository planRepository;
    private final SubscriptionOrderRepository orderRepository;
    private final UserDailyTokenUsageRepository tokenUsageRepository;
    private final SystemSettingRepository systemSettingRepository;
    private final UserRepository userRepository;

    @Value("${sepay.api-token:}")
    private String configuredSepayToken;

    private final HttpClient sepayHttpClient = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(3))
            .build();
    private final ObjectMapper objectMapper = new ObjectMapper();

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
        // Không bao giờ tạo đơn thanh toán QR cho gói FREE (0đ)
        if (plan != null && ("FREE".equalsIgnoreCase(plan.getCode())
                || (plan.getPrice() != null && plan.getPrice().compareTo(BigDecimal.ZERO) <= 0))) {
            plan = planRepository.findByCode("PRO_MONTHLY").orElse(null);
        }
        if (plan == null) {
            plan = planRepository.findAll().stream()
                    .filter(p -> p.getPrice() != null && p.getPrice().compareTo(BigDecimal.ZERO) > 0)
                    .findFirst()
                    .orElseGet(() -> planRepository.findAll().stream().findFirst()
                            .orElseThrow(() -> new AppException(404, "Không tìm thấy gói thành viên tương ứng")));
        }

        Long userId = request.getUserId() != null ? request.getUserId() : 1L;
        User user = userRepository.findById(userId)
                .orElseGet(() -> userRepository.findAll().stream().findFirst().orElse(null));

        if (user == null) {
            throw new AppException(404, "User not found");
        }

        long timestamp = System.currentTimeMillis();
        String orderCode = (request.getOrderCode() != null && !request.getOrderCode().isBlank())
                ? normalizeOrderCode(request.getOrderCode())
                : "TX-" + (timestamp % 1000000);
        String verificationCode = "JLSP-" + (int)(Math.random() * 90000 + 10000);

        // Chuẩn VietQR Napas 24/7 - Ngân hàng ACB - Ngân hàng TMCP Á Châu
        String bankBin = "970416";
        String accountNo = "28442991";
        String accountName = "PHAM CONG NGUYEN";
        BigDecimal finalAmount = plan.getPrice();
        if (request.getAmount() != null && request.getAmount().compareTo(BigDecimal.ZERO) > 0) {
            finalAmount = request.getAmount();
        }
        long priceLong = finalAmount.longValue();
        String addInfo = "JLSP " + orderCode;

        // Link mã QR VietQR Napas chuẩn quét được trên toàn bộ App ngân hàng Việt Nam
        String qrUrl = String.format(
                "https://img.vietqr.io/image/%s-%s-compact2.png?amount=%d&addInfo=%s&accountName=%s",
                bankBin, accountNo, priceLong, addInfo.replace(" ", "%20"), accountName.replace(" ", "%20")
        );

        SubscriptionOrder order = orderRepository.findByOrderCode(orderCode).orElse(null);
        if (order == null) {
            order = SubscriptionOrder.builder()
                    .orderCode(orderCode)
                    .verificationCode(verificationCode)
                    .user(user)
                    .plan(plan)
                    .amount(finalAmount)
                    .paymentMethod("VIETQR_NAPAS")
                    .status(SubscriptionOrder.OrderStatus.PENDING)
                    .qrUrl(qrUrl)
                    .build();
            order = orderRepository.save(order);
        }

        log.info("Created QR Payment Order {} for user {} (id={}) plan '{}' ({} VND)",
                order.getOrderCode(), user.getUsername(), user.getId(), plan.getName(), priceLong);
        return toOrderResponse(order);
    }

    @Override
    @Transactional
    public SubscriptionOrderResponse mockCheckout(CreateQrOrderRequest request) {
        SubscriptionOrderResponse order = createQrOrder(request);
        ConfirmPaymentRequest confirmReq = new ConfirmPaymentRequest();
        confirmReq.setOrderCode(order.getOrderCode());
        confirmReq.setVerificationCode(order.getVerificationCode());
        return confirmPayment(confirmReq);
    }

    private String normalizeOrderCode(String raw) {
        if (raw == null) return "";
        String cleaned = raw.trim().toUpperCase();
        java.util.regex.Matcher m = java.util.regex.Pattern.compile("TX[-\\s]*([0-9]+)").matcher(cleaned);
        if (m.find()) {
            return "TX-" + m.group(1);
        }
        return cleaned;
    }

    @Override
    @Transactional
    public SubscriptionOrderResponse confirmPayment(ConfirmPaymentRequest request) {
        String code = request.getVerificationCode() != null ? request.getVerificationCode().trim().toUpperCase() : "";
        String rawOrderCode = request.getOrderCode() != null ? request.getOrderCode().trim().toUpperCase() : "";
        String orderCode = normalizeOrderCode(rawOrderCode);

        SubscriptionOrder order = null;
        if ("LATEST_PENDING".equalsIgnoreCase(rawOrderCode)) {
            order = orderRepository.findFirstByStatusOrderByCreatedAtDesc(SubscriptionOrder.OrderStatus.PENDING).orElse(null);
        }
        if (order == null && !code.isBlank()) {
            order = orderRepository.findByVerificationCode(code).orElse(null);
            if (order == null) {
                order = orderRepository.findByOrderCode(normalizeOrderCode(code)).orElse(null);
            }
        }
        if (order == null && !orderCode.isBlank()) {
            order = orderRepository.findByOrderCode(orderCode).orElse(null);
            if (order == null && !rawOrderCode.equals(orderCode)) {
                order = orderRepository.findByOrderCode(rawOrderCode).orElse(null);
            }
        }
        if (order == null) {
            throw new AppException(400, "Không tìm thấy đơn hàng tương ứng với mã xác nhận hoặc mã đơn");
        }

        if (order.getStatus() == SubscriptionOrder.OrderStatus.SUCCESS) {
            return toOrderResponse(order);
        }

        order.setStatus(SubscriptionOrder.OrderStatus.SUCCESS);
        order.setCompletedAt(LocalDateTime.now());
        orderRepository.save(order);

        // Kích hoạt VIP cho User
        User user = order.getUser();
        if (user != null && order.getPlan() != null) {
            user.setSubscriptionPlan(order.getPlan());
            LocalDateTime currentExpire = user.getVipExpiresAt();
            LocalDateTime baseTime = (currentExpire != null && currentExpire.isAfter(LocalDateTime.now())) ? currentExpire : LocalDateTime.now();
            int durationDays = order.getPlan().getDurationDays() != null ? order.getPlan().getDurationDays() : 30;
            user.setVipExpiresAt(baseTime.plusDays(durationDays));
            userRepository.save(user);

            log.info("Payment CONFIRMED for order {} via code {}. User {} (id={}) upgraded to plan {} ({} days) with limit {} tokens/day!",
                    order.getOrderCode(), code, user.getUsername(), user.getId(), order.getPlan().getName(), durationDays, order.getPlan().getDailyTokenLimit());
        }

        return toOrderResponse(order);
    }

    @Override
    @Transactional
    public SubscriptionOrderResponse getOrderStatus(String orderCode) {
        String normalized = normalizeOrderCode(orderCode);
        SubscriptionOrder order = orderRepository.findByOrderCode(normalized)
                .or(() -> orderRepository.findByOrderCode(orderCode))
                .orElse(null);
        if (order == null) {
            return SubscriptionOrderResponse.builder()
                    .orderCode(normalized)
                    .status(SubscriptionOrder.OrderStatus.PENDING)
                    .bankName("ACB - Ngân hàng TMCP Á Châu")
                    .accountNo("28442991")
                    .accountName("PHAM CONG NGUYEN")
                    .build();
        }
        if (order.getStatus() == SubscriptionOrder.OrderStatus.PENDING) {
            order = checkSepayTransactionsForOrder(order);
        }
        return toOrderResponse(order);
    }

    private String resolveSepayApiToken() {
        if (configuredSepayToken != null && !configuredSepayToken.isBlank()) {
            return cleanSepayToken(configuredSepayToken);
        }
        try {
            return systemSettingRepository.findBySettingKey(SEPAY_TOKEN_SETTING_KEY)
                    .map(SystemSetting::getSettingValue)
                    .map(this::cleanSepayToken)
                    .orElse("");
        } catch (Exception e) {
            return "";
        }
    }

    private String cleanSepayToken(String raw) {
        if (raw == null) return "";
        String trimmed = raw.trim();
        if (trimmed.regionMatches(true, 0, "Bearer ", 0, 7)) {
            return trimmed.substring(7).trim();
        }
        if (trimmed.regionMatches(true, 0, "Apikey ", 0, 7)) {
            return trimmed.substring(7).trim();
        }
        return trimmed;
    }

    private SubscriptionOrder checkSepayTransactionsForOrder(SubscriptionOrder order) {
        String token = resolveSepayApiToken();
        if (token.isBlank()) {
            return order;
        }
        try {
            HttpRequest req = HttpRequest.newBuilder()
                    .uri(URI.create(SEPAY_TRANSACTIONS_API_URL))
                    .timeout(Duration.ofSeconds(4))
                    .header("Authorization", "Bearer " + token)
                    .header("Accept", "application/json")
                    .GET()
                    .build();
            HttpResponse<String> resp = sepayHttpClient.send(req, HttpResponse.BodyHandlers.ofString());
            if (resp.statusCode() != 200 || resp.body() == null || resp.body().isBlank()) {
                return order;
            }
            JsonNode root = objectMapper.readTree(resp.body());
            JsonNode transactions = root.path("transactions");
            if (!transactions.isArray()) {
                return order;
            }
            String orderDigits = order.getOrderCode() != null ? order.getOrderCode().replaceAll("[^0-9]", "") : "";
            String verifyDigits = order.getVerificationCode() != null ? order.getVerificationCode().replaceAll("[^0-9]", "") : "";

            for (JsonNode tx : transactions) {
                double amountIn = tx.path("amount_in").asDouble(0.0);
                if (amountIn <= 0) {
                    continue;
                }
                String txContent = (tx.path("transaction_content").asText("") + " "
                        + tx.path("code").asText("") + " "
                        + tx.path("description").asText("") + " "
                        + tx.path("reference_number").asText("")).toUpperCase();

                boolean matchedOrder = !orderDigits.isEmpty() && txContent.contains(orderDigits);
                boolean matchedVerify = !verifyDigits.isEmpty() && txContent.contains(verifyDigits);

                if (matchedOrder || matchedVerify) {
                    log.info("SePay Direct API matched transaction id={} content='{}' amount_in={} for order {}",
                            tx.path("id").asText(""), tx.path("transaction_content").asText(""), amountIn, order.getOrderCode());
                    ConfirmPaymentRequest confirmReq = new ConfirmPaymentRequest();
                    confirmReq.setOrderCode(order.getOrderCode());
                    confirmPayment(confirmReq);
                    return orderRepository.findByOrderCode(order.getOrderCode()).orElse(order);
                }
            }
        } catch (Exception e) {
            log.debug("SePay Direct API polling skipped/failed: {}", e.getMessage());
        }
        return order;
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

        SubscriptionPlan freePlan = planRepository.findByCode("FREE").orElse(null);
        int freeLimit = (freePlan != null && freePlan.getDailyTokenLimit() != null)
                ? freePlan.getDailyTokenLimit()
                : 50;
        String freePlanName = (freePlan != null && freePlan.getName() != null)
                ? freePlan.getName()
                : "Miễn phí (Free)";

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

        SubscriptionPlan freePlan = planRepository.findByCode("FREE").orElse(null);
        int freeLimit = (freePlan != null && freePlan.getDailyTokenLimit() != null)
                ? freePlan.getDailyTokenLimit()
                : 50;

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
                .bankName("ACB - Ngân hàng TMCP Á Châu")
                .accountNo("28442991")
                .accountName("PHAM CONG NGUYEN")
                .paymentWebUrl("/payment-confirm?code=" + order.getVerificationCode())
                .createdAt(order.getCreatedAt())
                .completedAt(order.getCompletedAt())
                .build();
    }

    @Override
    public Map<String, Object> getUserSubscriptionStatus(Long userId) {
        User user = userRepository.findById(userId).orElse(null);
        Map<String, Object> result = new HashMap<>();

        boolean isVip = false;
        Long planId = null;
        String planName = "Miễn phí (Free)";
        LocalDateTime endDate = null;
        int remainingDays = 0;
        int dailyTokenLimit = 50;

        if (user != null && user.getSubscriptionPlan() != null) {
            SubscriptionPlan plan = user.getSubscriptionPlan();
            LocalDateTime expire = user.getVipExpiresAt();
            boolean isFree = "FREE".equalsIgnoreCase(plan.getCode())
                    || (plan.getPrice() != null && plan.getPrice().compareTo(BigDecimal.ZERO) == 0);

            if (!isFree && (expire == null || expire.isAfter(LocalDateTime.now()))) {
                isVip = true;
                planId = plan.getId();
                planName = plan.getName();
                endDate = expire;
                if (plan.getDailyTokenLimit() != null) {
                    dailyTokenLimit = plan.getDailyTokenLimit();
                }
                if (expire != null) {
                    remainingDays = (int) java.time.temporal.ChronoUnit.DAYS.between(LocalDateTime.now(), expire);
                    if (remainingDays < 0) remainingDays = 0;
                } else {
                    remainingDays = 0;
                }
            }
        }

        result.put("isVip", isVip);
        result.put("planId", planId);
        result.put("planName", planName);
        result.put("status", isVip ? "ACTIVE" : "INACTIVE");
        result.put("startDate", LocalDateTime.now().toString());
        result.put("endDate", endDate != null ? endDate.toString() : null);
        result.put("remainingDays", remainingDays);
        result.put("dailyTokenLimit", dailyTokenLimit);
        return result;
    }

    @Override
    public Map<String, Object> verifyPromoCode(String rawCode, Long planId) {
        if (rawCode == null || rawCode.trim().isEmpty()) {
            throw new AppException(400, "Vui lòng nhập mã khuyến mãi");
        }
        String code = rawCode.trim().toUpperCase();
        Map<String, Object> res = new HashMap<>();
        res.put("code", code);

        switch (code) {
            case "JLSP10":
                res.put("valid", true);
                res.put("discountPercent", 10);
                res.put("discountAmount", 0);
                res.put("description", "Giảm 10% áp dụng cho toàn bộ các gói thành viên JLSP");
                return res;
            case "JLSP20":
                res.put("valid", true);
                res.put("discountPercent", 20);
                res.put("discountAmount", 0);
                res.put("description", "Ưu đãi chào mừng thành viên mới - Giảm 20%");
                return res;
            case "SENSEI":
                res.put("valid", true);
                res.put("discountPercent", 15);
                res.put("discountAmount", 0);
                res.put("description", "Ưu đãi đặc quyền Sensei & Giáo viên - Giảm 15%");
                return res;
            case "KOTOBA":
                res.put("valid", true);
                res.put("discountPercent", 0);
                res.put("discountAmount", 50000);
                res.put("description", "Giảm trực tiếp 50.000 VNĐ vào hóa đơn");
                return res;
            case "HARU2026":
                res.put("valid", true);
                res.put("discountPercent", 25);
                res.put("discountAmount", 0);
                res.put("description", "Chiến dịch luyện thi JLPT Mùa Xuân 2026 - Giảm 25%");
                return res;
            default:
                throw new AppException(400, "Mã khuyến mãi '" + code + "' không tồn tại hoặc đã hết hạn sử dụng. Vui lòng kiểm tra lại!");
        }
    }

    @Override
    @Transactional
    public Map<String, Object> cancelSubscription(Long userId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new AppException(404, "User không tồn tại"));

        SubscriptionPlan freePlan = planRepository.findByCode("FREE")
                .orElseGet(() -> planRepository.findAll().stream()
                        .filter(p -> p.getPrice() == null || p.getPrice().compareTo(BigDecimal.ZERO) == 0)
                        .findFirst()
                        .orElse(null));

        user.setSubscriptionPlan(freePlan);
        user.setVipExpiresAt(LocalDateTime.now());
        userRepository.save(user);

        log.info("User {} (id={}) cancelled subscription. Status reverted to FREE.", user.getUsername(), user.getId());

        Map<String, Object> result = getUserSubscriptionStatus(userId);
        result.put("message", "Đã hủy gói thành viên thành công. Tài khoản đã quay về Gói Cơ Bản (Free).");
        return result;
    }

    @Override
    @Transactional
    public Map<String, Object> saveSepayApiToken(String apiToken) {
        String cleaned = cleanSepayToken(apiToken);
        if (cleaned.isEmpty()) {
            throw new AppException(400, "SEPAY_API_TOKEN không được để trống");
        }
        this.configuredSepayToken = cleaned;
        SystemSetting setting = systemSettingRepository.findBySettingKey(SEPAY_TOKEN_SETTING_KEY)
                .orElseGet(() -> SystemSetting.builder()
                        .settingKey(SEPAY_TOKEN_SETTING_KEY)
                        .description("SePay User API Token for automatic ACB transaction polling")
                        .build());
        setting.setSettingValue(cleaned);
        systemSettingRepository.save(setting);
        log.info("Saved SEPAY_API_TOKEN to system_settings table successfully!");
        return getSepayTokenStatus();
    }

    @Override
    public Map<String, Object> getSepayTokenStatus() {
        String token = resolveSepayApiToken();
        Map<String, Object> status = new HashMap<>();
        boolean configured = !token.isBlank();
        status.put("configured", configured);
        status.put("maskedToken", configured && token.length() > 8
                ? token.substring(0, 4) + "..." + token.substring(token.length() - 4)
                : (configured ? "***" : ""));
        if (configured) {
            try {
                HttpRequest req = HttpRequest.newBuilder()
                        .uri(URI.create("https://my.sepay.vn/userapi/transactions/list?limit=3"))
                        .timeout(Duration.ofSeconds(5))
                        .header("Authorization", "Bearer " + token)
                        .header("Accept", "application/json")
                        .GET()
                        .build();
                HttpResponse<String> resp = sepayHttpClient.send(req, HttpResponse.BodyHandlers.ofString());
                status.put("sepayHttpStatus", resp.statusCode());
                status.put("connected", resp.statusCode() == 200);
                if (resp.statusCode() == 200 && resp.body() != null) {
                    JsonNode root = objectMapper.readTree(resp.body());
                    status.put("recentTransactionsCount", root.path("transactions").size());
                }
            } catch (Exception e) {
                status.put("connected", false);
                status.put("error", e.getMessage());
            }
        }
        return status;
    }
}
