package com.jlsp.backend.subscription.service.impl;

import com.jlsp.backend.common.exception.AppException;
import com.jlsp.backend.common.exception.ResourceNotFoundException;
import com.jlsp.backend.common.response.PageResponse;
import com.jlsp.backend.subscription.dto.request.CreateOrderRequest;
import com.jlsp.backend.subscription.dto.request.SepayWebhookPayload;
import com.jlsp.backend.subscription.dto.response.SubscriptionOrderResponse;
import com.jlsp.backend.subscription.entity.PaymentTransaction;
import com.jlsp.backend.subscription.entity.SubscriptionOrder;
import com.jlsp.backend.subscription.entity.SubscriptionOrder.OrderStatus;
import com.jlsp.backend.subscription.entity.SubscriptionPlan;
import com.jlsp.backend.subscription.payment.PaymentMemo;
import com.jlsp.backend.subscription.payment.PaymentProperties;
import com.jlsp.backend.subscription.payment.VietQrUrlBuilder;
import com.jlsp.backend.subscription.payment.WebhookResult;
import com.jlsp.backend.subscription.entity.PromoCode;
import com.jlsp.backend.subscription.repository.PaymentTransactionRepository;
import com.jlsp.backend.subscription.repository.PromoCodeRepository;
import com.jlsp.backend.subscription.repository.SubscriptionOrderRepository;
import com.jlsp.backend.subscription.repository.SubscriptionPlanRepository;
import com.jlsp.backend.subscription.service.PaymentService;
import com.jlsp.backend.user.entity.User;
import com.jlsp.backend.user.repository.UserRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Locale;
import java.util.Optional;

@Service
@Transactional
public class PaymentServiceImpl implements PaymentService {

    private static final Logger log = LoggerFactory.getLogger(PaymentServiceImpl.class);

    /** Gói có số ngày từ mức này trở lên được coi là trọn đời (dữ liệu cũ dùng 9999 / 36500). */
    static final int LIFETIME_DAYS_THRESHOLD = 3650;
    private static final int MEMO_ATTEMPTS = 5;

    private final SubscriptionPlanRepository planRepository;
    private final SubscriptionOrderRepository orderRepository;
    private final PaymentTransactionRepository transactionRepository;
    private final UserRepository userRepository;
    private final PaymentProperties props;
    private final Clock clock;
    private final PromoCodeRepository promoCodeRepository;

    @Autowired
    public PaymentServiceImpl(SubscriptionPlanRepository planRepository,
                              SubscriptionOrderRepository orderRepository,
                              PaymentTransactionRepository transactionRepository,
                              UserRepository userRepository,
                              PaymentProperties props,
                              PromoCodeRepository promoCodeRepository) {
        this(planRepository, orderRepository, transactionRepository, userRepository, props, Clock.systemDefaultZone(), promoCodeRepository);
    }

    PaymentServiceImpl(SubscriptionPlanRepository planRepository,
                       SubscriptionOrderRepository orderRepository,
                       PaymentTransactionRepository transactionRepository,
                       UserRepository userRepository,
                       PaymentProperties props,
                       Clock clock) {
        this(planRepository, orderRepository, transactionRepository, userRepository, props, clock, null);
    }

    PaymentServiceImpl(SubscriptionPlanRepository planRepository,
                       SubscriptionOrderRepository orderRepository,
                       PaymentTransactionRepository transactionRepository,
                       UserRepository userRepository,
                       PaymentProperties props,
                       Clock clock,
                       PromoCodeRepository promoCodeRepository) {
        this.planRepository = planRepository;
        this.orderRepository = orderRepository;
        this.transactionRepository = transactionRepository;
        this.userRepository = userRepository;
        this.props = props;
        this.clock = clock;
        this.promoCodeRepository = promoCodeRepository;
    }

    private LocalDateTime now() {
        return LocalDateTime.now(clock);
    }

    // ------------------------------------------------------------------ tạo và xem đơn

    @Override
    public SubscriptionOrderResponse createOrder(Long userId, CreateOrderRequest request) {
        if (!props.canCreateOrders()) {
            throw new AppException(503, "Thanh toán chuyển khoản chưa được bật. Vui lòng thử lại sau");
        }
        SubscriptionPlan plan = resolvePlan(request);
        if (plan.getPrice() == null || plan.getPrice().signum() <= 0) {
            throw new AppException(400, "Gói này miễn phí, không cần thanh toán");
        }
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new AppException(404, "Không tìm thấy tài khoản"));

        LocalDateTime now = now();

        boolean alreadyLifetime = user.getSubscriptionPlan() != null
                && user.getSubscriptionPlan().getPrice() != null
                && user.getSubscriptionPlan().getPrice().signum() > 0
                && user.getVipExpiresAt() == null;
        if (alreadyLifetime) {
            throw new AppException(400, "Bạn đang sở hữu gói Trọn Đời cao cấp nhất, không cần mua thêm");
        }

        BigDecimal originalPrice = plan.getPrice();
        BigDecimal finalAmount = originalPrice;
        BigDecimal discountAmount = BigDecimal.ZERO;
        String appliedPromo = null;

        if (request != null && request.getPromoCode() != null && !request.getPromoCode().isBlank() && promoCodeRepository != null) {
            String code = request.getPromoCode().trim().toUpperCase(Locale.ROOT);
            com.jlsp.backend.subscription.entity.PromoCode promo = promoCodeRepository.findByCodeIgnoreCase(code).orElse(null);
            if (promo != null && Boolean.TRUE.equals(promo.getIsActive())) {
                boolean validDates = (promo.getStartDate() == null || !now.isBefore(promo.getStartDate()))
                        && (promo.getEndDate() == null || !now.isAfter(promo.getEndDate()));
                boolean validUses = promo.getMaxUses() == null || promo.getUsedCount() == null || promo.getUsedCount() < promo.getMaxUses();
                if (validDates && validUses) {
                    appliedPromo = promo.getCode();
                    int percent = promo.getDiscountPercent() != null ? promo.getDiscountPercent() : 0;
                    BigDecimal fixed = promo.getDiscountAmount() != null ? promo.getDiscountAmount() : BigDecimal.ZERO;
                    if (percent > 0) {
                        discountAmount = originalPrice.multiply(BigDecimal.valueOf(percent)).divide(BigDecimal.valueOf(100), 0, java.math.RoundingMode.HALF_UP);
                    } else if (fixed.signum() > 0) {
                        discountAmount = fixed;
                    }
                    finalAmount = originalPrice.subtract(discountAmount);
                    if (finalAmount.compareTo(BigDecimal.valueOf(1000)) < 0) {
                        finalAmount = BigDecimal.valueOf(1000); // Tối thiểu 1.000 VND
                    }
                }
            }
        }

        // Bấm mua nhiều lần cho cùng một gói thì dùng lại đơn đang chờ (nếu cùng mã giảm giá)
        Optional<SubscriptionOrder> open = orderRepository
                .findFirstByUserIdAndPlanIdAndStatusAndExpiresAtAfterOrderByCreatedAtDesc(
                        userId, plan.getId(), OrderStatus.PENDING, now);
        if (open.isPresent()) {
            SubscriptionOrder existing = open.get();
            if (java.util.Objects.equals(existing.getPromoCode(), appliedPromo) && existing.getAmount().compareTo(finalAmount) == 0) {
                return toResponse(existing, now);
            } else {
                existing.setStatus(OrderStatus.EXPIRED);
                orderRepository.save(existing);
            }
        }
        if (orderRepository.countByUserIdAndCreatedAtAfter(userId, now.minusHours(1)) >= props.maxOrdersPerHour()) {
            throw new AppException(429, "Bạn tạo quá nhiều đơn trong một giờ. Vui lòng thử lại sau");
        }

        String memo = uniqueMemo();
        SubscriptionOrder order = SubscriptionOrder.builder()
                .orderCode(memo)
                .transferMemo(memo)
                .user(user)
                .plan(plan)
                .amount(finalAmount)
                .promoCode(appliedPromo)
                .discountAmount(discountAmount)
                .paymentMethod("VIETQR_NAPAS")
                .status(OrderStatus.PENDING)
                .qrUrl(VietQrUrlBuilder.build(props, finalAmount, memo))
                .expiresAt(now.plusMinutes(props.orderTtlMinutes()))
                .build();
        SubscriptionOrder saved = orderRepository.save(order);
        log.info("Tạo đơn thanh toán {} cho user {} gói {} ({} VND) [voucher={}]", memo, userId, plan.getCode(), finalAmount, appliedPromo);
        return toResponse(saved, now);
    }

    private SubscriptionPlan resolvePlan(CreateOrderRequest request) {
        SubscriptionPlan plan;
        if (request != null && request.getPlanId() != null) {
            plan = planRepository.findById(request.getPlanId())
                    .orElseThrow(() -> new AppException(404, "Không tìm thấy gói thành viên"));
        } else if (request != null && request.getPlanCode() != null && !request.getPlanCode().isBlank()) {
            plan = planRepository.findByCode(request.getPlanCode().trim().toUpperCase(Locale.ROOT))
                    .orElseThrow(() -> new AppException(404, "Không tìm thấy gói thành viên"));
        } else {
            throw new AppException(400, "Vui lòng chọn gói thành viên");
        }
        if (!Boolean.TRUE.equals(plan.getIsActive())) {
            throw new AppException(400, "Gói này hiện không còn được bán");
        }
        // Gói FREE không bao giờ bán, kể cả khi dữ liệu lỡ đặt giá khác 0.
        if ("FREE".equalsIgnoreCase(plan.getCode())) {
            throw new AppException(400, "Gói này miễn phí, không cần thanh toán");
        }
        return plan;
    }

    private String uniqueMemo() {
        for (int i = 0; i < MEMO_ATTEMPTS; i++) {
            String memo = PaymentMemo.generate();
            if (!orderRepository.existsByOrderCode(memo)) {
                return memo;
            }
        }
        throw new AppException(500, "Không tạo được mã đơn, vui lòng thử lại");
    }

    @Override
    @Transactional(readOnly = true)
    public SubscriptionOrderResponse getMyOrder(Long userId, String orderCode) {
        String code = orderCode == null ? "" : orderCode.trim().toUpperCase(Locale.ROOT);
        SubscriptionOrder order = orderRepository.findByOrderCode(code)
                .filter(o -> o.getUser() != null && userId != null && userId.equals(o.getUser().getId()))
                .orElseThrow(() -> new ResourceNotFoundException("SubscriptionOrder", "orderCode", orderCode));
        return toResponse(order, now());
    }

    @Override
    @Transactional(readOnly = true)
    public PageResponse<SubscriptionOrderResponse> getMyOrders(Long userId, Pageable pageable) {
        return toPage(orderRepository.findByUserId(userId, pageable));
    }

    @Override
    @Transactional(readOnly = true)
    public PageResponse<SubscriptionOrderResponse> getAllOrders(OrderStatus status, Pageable pageable) {
        Page<SubscriptionOrder> page = status != null
                ? orderRepository.findByStatus(status, pageable)
                : orderRepository.findAll(pageable);
        return toPage(page);
    }

    private PageResponse<SubscriptionOrderResponse> toPage(Page<SubscriptionOrder> page) {
        LocalDateTime now = now();
        List<SubscriptionOrderResponse> content = page.getContent().stream().map(o -> toResponse(o, now)).toList();
        return PageResponse.<SubscriptionOrderResponse>builder()
                .content(content)
                .page(page.getNumber())
                .size(page.getSize())
                .totalElements(page.getTotalElements())
                .totalPages(page.getTotalPages())
                .last(page.isLast())
                .build();
    }

    // ------------------------------------------------------------------ admin duyệt tay

    @Override
    public SubscriptionOrderResponse adminConfirm(String orderCode, Long adminId, String note) {
        String code = orderCode == null ? "" : orderCode.trim().toUpperCase(Locale.ROOT);
        SubscriptionOrder order = orderRepository.findByOrderCodeForUpdate(code)
                .orElseThrow(() -> new ResourceNotFoundException("SubscriptionOrder", "orderCode", orderCode));
        LocalDateTime now = now();
        if (order.getStatus() == OrderStatus.SUCCESS) {
            return toResponse(order, now);
        }
        if (order.getStatus() == OrderStatus.CANCELLED || order.getStatus() == OrderStatus.FAILED) {
            throw new AppException(400, "Đơn đã bị hủy, không thể duyệt");
        }
        order.setConfirmedBy(adminId);
        order.setNote(note);
        activate(order, "MANUAL:" + adminId, now);
        log.info("Admin {} duyệt tay đơn {} ({})", adminId, order.getOrderCode(), note);
        return toResponse(order, now);
    }

    // ------------------------------------------------------------------ webhook SePay

    @Override
    public WebhookResult handleSepayWebhook(SepayWebhookPayload payload) {
        if (payload == null || !"in".equalsIgnoreCase(trim(payload.getTransferType()))) {
            return WebhookResult.IGNORED;
        }
        // Chỉ nhận tiền vào đúng tài khoản của mình (khoá webhook đã xác thực người gửi, đây là lớp kiểm tra thêm).
        String account = digits(payload.getAccountNumber());
        if (account.isEmpty() || !account.equals(digits(props.accountNo()))) {
            log.warn("Webhook SePay bỏ qua: sai tài khoản nhận (id={})", payload.getId());
            return WebhookResult.IGNORED;
        }
        BigDecimal amount = payload.getTransferAmount();
        if (payload.getId() == null || amount == null || amount.signum() <= 0) {
            log.warn("Webhook SePay bỏ qua: thiếu mã giao dịch hoặc số tiền không hợp lệ");
            return WebhookResult.IGNORED;
        }

        String externalId = String.valueOf(payload.getId());
        if (transactionRepository.existsByGatewayAndExternalId(PaymentTransaction.GATEWAY_SEPAY, externalId)) {
            return WebhookResult.DUPLICATE;
        }
        // Ghi sổ cái trước và flush để ràng buộc duy nhất chặn ngay hai webhook trùng chạy đồng thời.
        PaymentTransaction tx = transactionRepository.saveAndFlush(PaymentTransaction.builder()
                .gateway(PaymentTransaction.GATEWAY_SEPAY)
                .externalId(externalId)
                .amount(amount)
                .accountNumber(account)
                .content(payload.getContent())
                .referenceCode(payload.getReferenceCode())
                .transactionTime(payload.getTransactionDate())
                .status(PaymentTransaction.Status.UNMATCHED)
                .build());

        String memo = PaymentMemo.extract(payload.getContent(), payload.getCode(), payload.getDescription());
        Optional<SubscriptionOrder> found = memo == null
                ? Optional.empty() : orderRepository.findByOrderCodeForUpdate(memo);
        if (found.isEmpty()) {
            log.info("Giao dịch {} ({} VND) không khớp đơn nào", externalId, amount);
            return WebhookResult.UNMATCHED;
        }

        SubscriptionOrder order = found.get();
        LocalDateTime now = now();
        tx.setOrderId(order.getId());

        if (order.getStatus() == OrderStatus.SUCCESS) {
            tx.setStatus(PaymentTransaction.Status.EXTRA_PAYMENT);
            log.warn("Giao dịch {} ({} VND) trả thêm cho đơn {} đã thanh toán: cần hoàn tiền", externalId, amount, memo);
            return WebhookResult.EXTRA_PAYMENT;
        }

        BigDecimal total = (order.getPaidAmount() == null ? BigDecimal.ZERO : order.getPaidAmount()).add(amount);
        order.setPaidAmount(total);

        if (!withinPaymentWindow(order, now)) {
            // Về quá muộn (hoặc đơn đã hủy): không tự kích hoạt, để admin quyết định.
            if (order.getStatus() != OrderStatus.CANCELLED && order.getStatus() != OrderStatus.FAILED) {
                order.setStatus(OrderStatus.NEEDS_REVIEW);
            }
            tx.setStatus(PaymentTransaction.Status.LATE);
            log.warn("Giao dịch {} cho đơn {} về quá muộn: cần admin xem xét", externalId, memo);
            return WebhookResult.LATE;
        }

        if (total.compareTo(order.getAmount()) >= 0) {
            activate(order, externalId, now);
            tx.setStatus(PaymentTransaction.Status.MATCHED);
            return WebhookResult.ACTIVATED;
        }

        order.setStatus(OrderStatus.NEEDS_REVIEW);
        tx.setStatus(PaymentTransaction.Status.UNDERPAID);
        log.info("Đơn {} mới nhận {}/{} VND", memo, total, order.getAmount());
        return WebhookResult.UNDERPAID;
    }

    /** Còn hạn thanh toán, hoặc đã hết hạn nhưng trong thời gian ân hạn. Đơn đã hủy không còn nhận tiền. */
    private boolean withinPaymentWindow(SubscriptionOrder order, LocalDateTime now) {
        OrderStatus status = order.getStatus();
        if (status != OrderStatus.PENDING && status != OrderStatus.EXPIRED && status != OrderStatus.NEEDS_REVIEW) {
            return false;
        }
        LocalDateTime deadline = order.getExpiresAt() == null
                ? null : order.getExpiresAt().plusHours(props.lateGraceHours());
        return deadline == null || !now.isAfter(deadline);
    }

    // ------------------------------------------------------------------ kích hoạt gói

    /** Đánh dấu đơn thành công và cộng hạn VIP; phải gọi khi đã khoá dòng đơn. */
    private void activate(SubscriptionOrder order, String bankTransactionId, LocalDateTime now) {
        User user = userRepository.findByIdForUpdate(order.getUser().getId())
                .orElseThrow(() -> new AppException(404, "Không tìm thấy tài khoản của đơn " + order.getOrderCode()));
        SubscriptionPlan newPlan = order.getPlan();
        SubscriptionPlan currentPlan = user.getSubscriptionPlan();
        LocalDateTime currentExpiresAt = user.getVipExpiresAt();

        boolean isCurrentlyVip = currentPlan != null
                && currentPlan.getPrice() != null
                && currentPlan.getPrice().signum() > 0
                && (currentExpiresAt == null || currentExpiresAt.isAfter(now));

        boolean alreadyLifetime = isCurrentlyVip && currentExpiresAt == null;

        if (isLifetime(newPlan)) {
            user.setSubscriptionPlan(newPlan);
            user.setVipExpiresAt(null);
        } else if (!alreadyLifetime) {
            if (!isCurrentlyVip) {
                // 1. Chưa có VIP hoặc VIP cũ đã hết hạn: kích hoạt mới từ thời điểm hiện tại
                user.setSubscriptionPlan(newPlan);
                user.setVipExpiresAt(now.plusDays(newPlan.getDurationDays()));
            } else {
                // 2. Đang có VIP còn hạn:
                boolean isSamePlan = currentPlan.getId().equals(newPlan.getId());
                boolean isHigherTier = isPlanHigherTier(newPlan, currentPlan);

                if (isSamePlan) {
                    // Gia hạn cùng gói: giữ nguyên gói, cộng dồn ngày vào mốc hết hạn hiện tại
                    LocalDateTime base = currentExpiresAt.isAfter(now) ? currentExpiresAt : now;
                    user.setVipExpiresAt(base.plusDays(newPlan.getDurationDays()));
                } else if (isHigherTier) {
                    // Nâng cấp lên gói cao hơn: chuyển sang gói mới cao cấp hơn
                    user.setSubscriptionPlan(newPlan);
                    LocalDateTime base = currentExpiresAt.isAfter(now) ? currentExpiresAt : now;
                    user.setVipExpiresAt(base.plusDays(newPlan.getDurationDays()));
                } else {
                    // Mua gói thấp hơn (hoặc gói test) khi đang có gói cao hơn còn hạn:
                    // Giữ nguyên gói cao hơn (không hạ cấp quyền lợi / token của user!)
                    // Thời hạn cộng dồn thêm vào đuôi
                    LocalDateTime base = currentExpiresAt.isAfter(now) ? currentExpiresAt : now;
                    user.setVipExpiresAt(base.plusDays(newPlan.getDurationDays()));
                    log.info("User {} mua gói thấp hơn ({}) trong khi đang có gói cao hơn ({}), giữ nguyên gói cao hơn và cộng thêm {} ngày",
                            user.getId(), newPlan.getCode(), currentPlan.getCode(), newPlan.getDurationDays());
                }
            }
        }
        userRepository.save(user);

        order.setStatus(OrderStatus.SUCCESS);
        order.setCompletedAt(now);
        order.setBankTransactionId(bankTransactionId);
        if (order.getPaidAmount() == null) {
            order.setPaidAmount(order.getAmount());
        }
        orderRepository.save(order);

        if (order.getPromoCode() != null && !order.getPromoCode().isBlank() && promoCodeRepository != null) {
            promoCodeRepository.findByCodeIgnoreCase(order.getPromoCode()).ifPresent(promo -> {
                promo.setUsedCount((promo.getUsedCount() != null ? promo.getUsedCount() : 0) + 1);
                promoCodeRepository.save(promo);
            });
        }

        log.info("Đơn {} thành công: user {} hiện có gói {}", order.getOrderCode(), user.getId(), user.getSubscriptionPlan().getCode());
    }

    private boolean isPlanHigherTier(SubscriptionPlan newPlan, SubscriptionPlan currentPlan) {
        if (newPlan == null || currentPlan == null) return false;
        if (isLifetime(newPlan)) return true;
        if (isLifetime(currentPlan)) return false;
        if (newPlan.getPrice() != null && currentPlan.getPrice() != null) {
            int cmp = newPlan.getPrice().compareTo(currentPlan.getPrice());
            if (cmp != 0) return cmp > 0;
        }
        return (newPlan.getDurationDays() != null ? newPlan.getDurationDays() : 0)
                > (currentPlan.getDurationDays() != null ? currentPlan.getDurationDays() : 0);
    }

    static boolean isLifetime(SubscriptionPlan plan) {
        return plan.getDurationDays() == null || plan.getDurationDays() >= LIFETIME_DAYS_THRESHOLD;
    }

    // ------------------------------------------------------------------ hết hạn

    @Override
    public int expirePendingOrders() {
        return orderRepository.expirePendingBefore(now());
    }

    // ------------------------------------------------------------------ chuyển đổi

    private SubscriptionOrderResponse toResponse(SubscriptionOrder order, LocalDateTime now) {
        User user = order.getUser();
        SubscriptionPlan plan = order.getPlan();
        OrderStatus status = order.getStatus();
        // Job dọn đơn chạy mỗi phút; trả EXPIRED ngay khi hết hạn để giao diện không phải đợi job.
        if (status == OrderStatus.PENDING && order.getExpiresAt() != null && now.isAfter(order.getExpiresAt())) {
            status = OrderStatus.EXPIRED;
        }
        return SubscriptionOrderResponse.builder()
                .id(order.getId())
                .orderCode(order.getOrderCode())
                .transferMemo(order.getTransferMemo())
                .userId(user != null ? user.getId() : null)
                .username(user != null ? user.getUsername() : null)
                .userEmail(user != null ? user.getEmail() : null)
                .planId(plan != null ? plan.getId() : null)
                .planName(plan != null ? plan.getName() : null)
                .dailyTokenLimit(plan != null ? plan.getDailyTokenLimit() : null)
                .amount(order.getAmount())
                .paidAmount(order.getPaidAmount())
                .promoCode(order.getPromoCode())
                .discountAmount(order.getDiscountAmount())
                .paymentMethod(order.getPaymentMethod())
                .status(status)
                .qrUrl(qrUrlFor(order))
                .bankName(props.bankName())
                .accountNo(props.accountNo())
                .accountName(props.accountName())
                .expiresAt(order.getExpiresAt())
                .createdAt(order.getCreatedAt())
                .completedAt(order.getCompletedAt())
                .build();
    }

    /**
     * Link ảnh QR dựng lại từ cấu hình hiện tại thay vì dùng link đã lưu trong đơn: đơn cũ có thể lưu link đã hỏng
     * (vd. đuôi .png không còn được dịch vụ ảnh hỗ trợ) hoặc tài khoản nhận đã đổi. Đơn quá cũ không có mã chuyển
     * khoản thì dùng link đã lưu.
     */
    private String qrUrlFor(SubscriptionOrder order) {
        String memo = order.getTransferMemo();
        if (memo == null || memo.isBlank() || order.getAmount() == null || !props.canCreateOrders()) {
            return order.getQrUrl();
        }
        return VietQrUrlBuilder.build(props, order.getAmount(), memo);
    }

    private static String trim(String s) {
        return s == null ? "" : s.trim();
    }

    private static String digits(String s) {
        return s == null ? "" : s.replaceAll("\\D", "");
    }
}
