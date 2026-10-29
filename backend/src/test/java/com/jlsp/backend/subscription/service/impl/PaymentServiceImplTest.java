package com.jlsp.backend.subscription.service.impl;

import com.jlsp.backend.common.exception.AppException;
import com.jlsp.backend.common.exception.ResourceNotFoundException;
import com.jlsp.backend.subscription.dto.request.CreateOrderRequest;
import com.jlsp.backend.subscription.dto.request.SepayWebhookPayload;
import com.jlsp.backend.subscription.dto.response.SubscriptionOrderResponse;
import com.jlsp.backend.subscription.entity.PaymentTransaction;
import com.jlsp.backend.subscription.entity.SubscriptionOrder;
import com.jlsp.backend.subscription.entity.SubscriptionOrder.OrderStatus;
import com.jlsp.backend.subscription.entity.SubscriptionPlan;
import com.jlsp.backend.subscription.payment.PaymentProperties;
import com.jlsp.backend.subscription.payment.WebhookResult;
import com.jlsp.backend.subscription.repository.PaymentTransactionRepository;
import com.jlsp.backend.subscription.repository.SubscriptionOrderRepository;
import com.jlsp.backend.subscription.repository.SubscriptionPlanRepository;
import com.jlsp.backend.user.entity.User;
import com.jlsp.backend.user.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class PaymentServiceImplTest {

    private static final Instant INSTANT = Instant.parse("2026-10-29T03:00:00Z");
    private static final LocalDateTime NOW = LocalDateTime.ofInstant(INSTANT, ZoneOffset.UTC);
    private static final String ACCOUNT = "28442991";
    private static final String MEMO = "JLSP7K3Q9M2X";
    private static final long USER_ID = 7L;

    private SubscriptionPlanRepository planRepository;
    private SubscriptionOrderRepository orderRepository;
    private PaymentTransactionRepository transactionRepository;
    private UserRepository userRepository;
    private PaymentServiceImpl service;

    private SubscriptionPlan monthly;
    private SubscriptionPlan lifetime;
    private User user;

    private static PaymentProperties props(boolean enabled, String account) {
        return new PaymentProperties(enabled, "970416", "ACB", account, "PHAM CONG NGUYEN", 15, 24, 3, "key");
    }

    @BeforeEach
    void setUp() {
        planRepository = mock(SubscriptionPlanRepository.class);
        orderRepository = mock(SubscriptionOrderRepository.class);
        transactionRepository = mock(PaymentTransactionRepository.class);
        userRepository = mock(UserRepository.class);
        service = newService(props(true, ACCOUNT));

        monthly = SubscriptionPlan.builder().id(2L).code("PRO_MONTHLY").name("Pro tháng")
                .price(new BigDecimal("99000")).durationDays(30).dailyTokenLimit(500).isActive(true).build();
        lifetime = SubscriptionPlan.builder().id(4L).code("VIP_SPECIAL").name("Trọn đời")
                .price(new BigDecimal("999000")).durationDays(36500).dailyTokenLimit(5000).isActive(true).build();
        user = User.builder().id(USER_ID).username("sakura").email("sakura@example.com").build();

        when(planRepository.findById(2L)).thenReturn(Optional.of(monthly));
        when(planRepository.findByCode("PRO_MONTHLY")).thenReturn(Optional.of(monthly));
        when(userRepository.findById(USER_ID)).thenReturn(Optional.of(user));
        when(userRepository.findByIdForUpdate(USER_ID)).thenReturn(Optional.of(user));
        when(userRepository.save(any(User.class))).thenAnswer(inv -> inv.getArgument(0));
        when(orderRepository.save(any(SubscriptionOrder.class))).thenAnswer(inv -> inv.getArgument(0));
        when(transactionRepository.saveAndFlush(any(PaymentTransaction.class))).thenAnswer(inv -> inv.getArgument(0));
    }

    private PaymentServiceImpl newService(PaymentProperties props) {
        return new PaymentServiceImpl(planRepository, orderRepository, transactionRepository, userRepository, props,
                Clock.fixed(INSTANT, ZoneOffset.UTC));
    }

    private SubscriptionOrder pendingOrder() {
        return SubscriptionOrder.builder().id(11L).orderCode(MEMO).transferMemo(MEMO).user(user).plan(monthly)
                .amount(monthly.getPrice()).status(OrderStatus.PENDING).expiresAt(NOW.plusMinutes(10))
                .createdAt(NOW.minusMinutes(5)).build();
    }

    private void givenOrder(SubscriptionOrder order) {
        when(orderRepository.findByOrderCodeForUpdate(order.getOrderCode())).thenReturn(Optional.of(order));
    }

    private static SepayWebhookPayload payload(long id, String amount, String content) {
        SepayWebhookPayload p = new SepayWebhookPayload();
        p.setId(id);
        p.setAccountNumber(ACCOUNT);
        p.setTransferType("in");
        p.setTransferAmount(new BigDecimal(amount));
        p.setContent(content);
        p.setTransactionDate("2026-10-29 10:00:00");
        return p;
    }

    // ================================================================== tạo đơn

    @Test
    void newOrderIsForTheTokenUserWithTheServerPriceMemoAndExpiry() {
        CreateOrderRequest request = CreateOrderRequest.builder().planCode("pro_monthly").build();

        SubscriptionOrderResponse response = service.createOrder(USER_ID, request);

        ArgumentCaptor<SubscriptionOrder> saved = ArgumentCaptor.forClass(SubscriptionOrder.class);
        verify(orderRepository).save(saved.capture());
        SubscriptionOrder order = saved.getValue();
        assertThat(order.getUser()).isSameAs(user);
        assertThat(order.getAmount()).isEqualByComparingTo("99000");
        assertThat(order.getStatus()).isEqualTo(OrderStatus.PENDING);
        assertThat(order.getOrderCode()).matches("JLSP[A-HJ-NP-Z2-9]{8}").isEqualTo(order.getTransferMemo());
        assertThat(order.getExpiresAt()).isEqualTo(NOW.plusMinutes(15));
        assertThat(order.getQrUrl()).contains("amount=99000").contains("addInfo=" + order.getTransferMemo());
        assertThat(response.getAccountNo()).isEqualTo(ACCOUNT);
        assertThat(response.getBankName()).isEqualTo("ACB");
    }

    @Test
    void buyingTheSamePlanAgainReopensThePendingOrderInsteadOfCreatingAnother() {
        SubscriptionOrder open = pendingOrder();
        when(orderRepository.findFirstByUserIdAndPlanIdAndStatusAndExpiresAtAfterOrderByCreatedAtDesc(
                USER_ID, 2L, OrderStatus.PENDING, NOW)).thenReturn(Optional.of(open));

        SubscriptionOrderResponse response = service.createOrder(USER_ID, CreateOrderRequest.builder().planId(2L).build());

        assertThat(response.getOrderCode()).isEqualTo(MEMO);
        verify(orderRepository, never()).save(any());
    }

    @Test
    void freeInactiveUnknownOrMissingPlansAreRejected() {
        SubscriptionPlan free = SubscriptionPlan.builder().id(1L).code("FREE").price(BigDecimal.ZERO)
                .durationDays(9999).isActive(true).build();
        SubscriptionPlan retired = SubscriptionPlan.builder().id(3L).code("OLD").price(new BigDecimal("1000"))
                .durationDays(30).isActive(false).build();
        when(planRepository.findById(1L)).thenReturn(Optional.of(free));
        when(planRepository.findById(3L)).thenReturn(Optional.of(retired));
        when(planRepository.findById(99L)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.createOrder(USER_ID, CreateOrderRequest.builder().planId(1L).build()))
                .isInstanceOfSatisfying(AppException.class, e -> assertThat(e.getStatus()).isEqualTo(400));
        assertThatThrownBy(() -> service.createOrder(USER_ID, CreateOrderRequest.builder().planId(3L).build()))
                .isInstanceOfSatisfying(AppException.class, e -> assertThat(e.getStatus()).isEqualTo(400));
        assertThatThrownBy(() -> service.createOrder(USER_ID, CreateOrderRequest.builder().planId(99L).build()))
                .isInstanceOfSatisfying(AppException.class, e -> assertThat(e.getStatus()).isEqualTo(404));
        assertThatThrownBy(() -> service.createOrder(USER_ID, new CreateOrderRequest()))
                .isInstanceOfSatisfying(AppException.class, e -> assertThat(e.getStatus()).isEqualTo(400));
        verify(orderRepository, never()).save(any());
    }

    @Test
    void theFreePlanIsNeverSoldEvenIfItsPriceWasChangedToNonZero() {
        SubscriptionPlan pricedFree = SubscriptionPlan.builder().id(1L).code("FREE").price(new BigDecimal("5000"))
                .durationDays(9999).isActive(true).build();
        when(planRepository.findById(1L)).thenReturn(Optional.of(pricedFree));

        assertThatThrownBy(() -> service.createOrder(USER_ID, CreateOrderRequest.builder().planId(1L).build()))
                .isInstanceOfSatisfying(AppException.class, e -> assertThat(e.getStatus()).isEqualTo(400));
        verify(orderRepository, never()).save(any());
    }

    @Test
    void ordersCannotBeCreatedWhenPaymentsAreNotConfigured() {
        PaymentServiceImpl noBank = newService(props(true, ""));

        assertThatThrownBy(() -> noBank.createOrder(USER_ID, CreateOrderRequest.builder().planId(2L).build()))
                .isInstanceOfSatisfying(AppException.class, e -> assertThat(e.getStatus()).isEqualTo(503));
    }

    @Test
    void tooManyOrdersInAnHourAreRejected() {
        when(orderRepository.countByUserIdAndCreatedAtAfter(USER_ID, NOW.minusHours(1))).thenReturn(3L);

        assertThatThrownBy(() -> service.createOrder(USER_ID, CreateOrderRequest.builder().planId(2L).build()))
                .isInstanceOfSatisfying(AppException.class, e -> assertThat(e.getStatus()).isEqualTo(429));
    }

    // ================================================================== xem đơn

    @Test
    void anOrderIsOnlyVisibleToItsOwner() {
        when(orderRepository.findByOrderCode(MEMO)).thenReturn(Optional.of(pendingOrder()));

        assertThat(service.getMyOrder(USER_ID, MEMO).getOrderCode()).isEqualTo(MEMO);
        assertThat(service.getMyOrder(USER_ID, " " + MEMO.toLowerCase() + " ").getOrderCode()).isEqualTo(MEMO);
        assertThatThrownBy(() -> service.getMyOrder(999L, MEMO)).isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void anOverduePendingOrderIsReportedAsExpiredEvenBeforeTheJobRuns() {
        SubscriptionOrder old = pendingOrder();
        old.setExpiresAt(NOW.minusMinutes(1));
        when(orderRepository.findByOrderCode(MEMO)).thenReturn(Optional.of(old));

        assertThat(service.getMyOrder(USER_ID, MEMO).getStatus()).isEqualTo(OrderStatus.EXPIRED);
    }

    @Test
    void theQrLinkIsRebuiltFromTheCurrentConfigSoOldBrokenLinksAreFixed() {
        SubscriptionOrder order = pendingOrder();
        order.setQrUrl("https://img.vietqr.io/image/970416-28442991-compact2.png?amount=99000&addInfo=OLD");
        when(orderRepository.findByOrderCode(MEMO)).thenReturn(Optional.of(order));

        String qr = service.getMyOrder(USER_ID, MEMO).getQrUrl();

        assertThat(qr).isEqualTo("https://img.vietqr.io/image/970416-28442991-compact2.svg"
                + "?amount=99000&addInfo=" + MEMO + "&accountName=PHAM%20CONG%20NGUYEN");
    }

    @Test
    void anOldOrderWithoutAMemoKeepsItsStoredQrLink() {
        SubscriptionOrder legacy = pendingOrder();
        legacy.setTransferMemo(null);
        legacy.setQrUrl("https://example.test/legacy-qr");
        when(orderRepository.findByOrderCode(MEMO)).thenReturn(Optional.of(legacy));

        assertThat(service.getMyOrder(USER_ID, MEMO).getQrUrl()).isEqualTo("https://example.test/legacy-qr");
    }

    @Test
    void viewingAnOrderNeverActivatesIt() {
        SubscriptionOrder order = pendingOrder();
        when(orderRepository.findByOrderCode(MEMO)).thenReturn(Optional.of(order));

        service.getMyOrder(USER_ID, MEMO);

        assertThat(order.getStatus()).isEqualTo(OrderStatus.PENDING);
        assertThat(user.getSubscriptionPlan()).isNull();
        verify(userRepository, never()).save(any());
    }

    // ================================================================== webhook: bỏ qua

    @Test
    void outgoingMoneyWrongAccountAndMalformedPayloadsAreIgnored() {
        SepayWebhookPayload out = payload(1, "99000", MEMO);
        out.setTransferType("out");
        SepayWebhookPayload wrongAccount = payload(2, "99000", MEMO);
        wrongAccount.setAccountNumber("11112222");
        SepayWebhookPayload noAccount = payload(3, "99000", MEMO);
        noAccount.setAccountNumber(null);
        SepayWebhookPayload noId = payload(4, "99000", MEMO);
        noId.setId(null);
        SepayWebhookPayload zero = payload(5, "0", MEMO);
        SepayWebhookPayload negative = payload(6, "-5", MEMO);

        for (SepayWebhookPayload p : new SepayWebhookPayload[]{null, out, wrongAccount, noAccount, noId, zero, negative}) {
            assertThat(service.handleSepayWebhook(p)).isEqualTo(WebhookResult.IGNORED);
        }
        verify(transactionRepository, never()).saveAndFlush(any());
        verify(userRepository, never()).save(any());
    }

    @Test
    void aTransactionSeenBeforeIsADuplicateAndChangesNothing() {
        SubscriptionOrder order = pendingOrder();
        givenOrder(order);
        when(transactionRepository.existsByGatewayAndExternalId("SEPAY", "100")).thenReturn(true);

        assertThat(service.handleSepayWebhook(payload(100, "99000", MEMO))).isEqualTo(WebhookResult.DUPLICATE);

        assertThat(order.getStatus()).isEqualTo(OrderStatus.PENDING);
        verify(transactionRepository, never()).saveAndFlush(any());
    }

    @Test
    void aTransferWithoutOurMemoIsRecordedAsUnmatched() {
        assertThat(service.handleSepayWebhook(payload(101, "50000", "tien an trua"))).isEqualTo(WebhookResult.UNMATCHED);

        ArgumentCaptor<PaymentTransaction> tx = ArgumentCaptor.forClass(PaymentTransaction.class);
        verify(transactionRepository).saveAndFlush(tx.capture());
        assertThat(tx.getValue().getStatus()).isEqualTo(PaymentTransaction.Status.UNMATCHED);
        assertThat(tx.getValue().getExternalId()).isEqualTo("101");
        verify(userRepository, never()).save(any());
    }

    @Test
    void aMemoOfAnUnknownOrderIsUnmatched() {
        when(orderRepository.findByOrderCodeForUpdate(anyString())).thenReturn(Optional.empty());

        assertThat(service.handleSepayWebhook(payload(102, "99000", MEMO))).isEqualTo(WebhookResult.UNMATCHED);
        verify(userRepository, never()).save(any());
    }

    @Test
    void anEmptyOrGarbagePayloadNeverActivatesAnything() {
        // Trước đây một webhook rỗng bất kỳ kích hoạt "đơn chờ mới nhất": giờ phải không làm gì cả.
        SepayWebhookPayload empty = new SepayWebhookPayload();
        SubscriptionOrder order = pendingOrder();
        givenOrder(order);

        assertThat(service.handleSepayWebhook(empty)).isEqualTo(WebhookResult.IGNORED);
        assertThat(service.handleSepayWebhook(payload(103, "99000", "xin chao"))).isEqualTo(WebhookResult.UNMATCHED);

        assertThat(order.getStatus()).isEqualTo(OrderStatus.PENDING);
        assertThat(user.getSubscriptionPlan()).isNull();
    }

    // ================================================================== webhook: kích hoạt

    @Test
    void fullPaymentActivatesTheOrderAndGivesVipForThePlanDuration() {
        SubscriptionOrder order = pendingOrder();
        givenOrder(order);

        WebhookResult result = service.handleSepayWebhook(payload(200, "99000", "MBVCB jlsp 7k3q-9m2x chuyen tien"));

        assertThat(result).isEqualTo(WebhookResult.ACTIVATED);
        assertThat(order.getStatus()).isEqualTo(OrderStatus.SUCCESS);
        assertThat(order.getCompletedAt()).isEqualTo(NOW);
        assertThat(order.getBankTransactionId()).isEqualTo("200");
        assertThat(order.getPaidAmount()).isEqualByComparingTo("99000");
        assertThat(user.getSubscriptionPlan()).isSameAs(monthly);
        assertThat(user.getVipExpiresAt()).isEqualTo(NOW.plusDays(30));

        ArgumentCaptor<PaymentTransaction> tx = ArgumentCaptor.forClass(PaymentTransaction.class);
        verify(transactionRepository).saveAndFlush(tx.capture());
        assertThat(tx.getValue().getStatus()).isEqualTo(PaymentTransaction.Status.MATCHED);
        assertThat(tx.getValue().getOrderId()).isEqualTo(11L);
    }

    @Test
    void overpaymentStillActivates() {
        SubscriptionOrder order = pendingOrder();
        givenOrder(order);

        assertThat(service.handleSepayWebhook(payload(201, "150000", MEMO))).isEqualTo(WebhookResult.ACTIVATED);
        assertThat(order.getPaidAmount()).isEqualByComparingTo("150000");
    }

    @Test
    void underpaymentDoesNotActivateButTheTopUpDoes() {
        SubscriptionOrder order = pendingOrder();
        givenOrder(order);

        assertThat(service.handleSepayWebhook(payload(202, "50000", MEMO))).isEqualTo(WebhookResult.UNDERPAID);
        assertThat(order.getStatus()).isEqualTo(OrderStatus.NEEDS_REVIEW);
        assertThat(order.getPaidAmount()).isEqualByComparingTo("50000");
        assertThat(user.getSubscriptionPlan()).isNull();

        assertThat(service.handleSepayWebhook(payload(203, "49000", MEMO))).isEqualTo(WebhookResult.ACTIVATED);
        assertThat(order.getStatus()).isEqualTo(OrderStatus.SUCCESS);
        assertThat(order.getPaidAmount()).isEqualByComparingTo("99000");
        assertThat(user.getSubscriptionPlan()).isSameAs(monthly);
    }

    @Test
    void anActiveVipExtendsFromItsCurrentExpiryNotFromToday() {
        user.setSubscriptionPlan(monthly);
        user.setVipExpiresAt(NOW.plusDays(10));
        givenOrder(pendingOrder());

        service.handleSepayWebhook(payload(204, "99000", MEMO));

        assertThat(user.getVipExpiresAt()).isEqualTo(NOW.plusDays(40));
    }

    @Test
    void anExpiredVipRestartsFromToday() {
        user.setSubscriptionPlan(monthly);
        user.setVipExpiresAt(NOW.minusDays(3));
        givenOrder(pendingOrder());

        service.handleSepayWebhook(payload(205, "99000", MEMO));

        assertThat(user.getVipExpiresAt()).isEqualTo(NOW.plusDays(30));
    }

    @Test
    void aLifetimePlanHasNoExpiryAndAFixedTermPurchaseDoesNotRemoveIt() {
        SubscriptionOrder lifetimeOrder = pendingOrder();
        lifetimeOrder.setPlan(lifetime);
        lifetimeOrder.setAmount(lifetime.getPrice());
        givenOrder(lifetimeOrder);
        service.handleSepayWebhook(payload(206, "999000", MEMO));
        assertThat(user.getSubscriptionPlan()).isSameAs(lifetime);
        assertThat(user.getVipExpiresAt()).isNull();

        // Đang trọn đời mà mua thêm gói tháng: vẫn trọn đời, đơn vẫn ghi nhận thành công.
        SubscriptionOrder monthlyOrder = pendingOrder();
        monthlyOrder.setOrderCode("JLSPAAAA2222");
        monthlyOrder.setTransferMemo("JLSPAAAA2222");
        when(orderRepository.findByOrderCodeForUpdate("JLSPAAAA2222")).thenReturn(Optional.of(monthlyOrder));
        service.handleSepayWebhook(payload(207, "99000", "JLSPAAAA2222"));
        assertThat(monthlyOrder.getStatus()).isEqualTo(OrderStatus.SUCCESS);
        assertThat(user.getSubscriptionPlan()).isSameAs(lifetime);
        assertThat(user.getVipExpiresAt()).isNull();
    }

    @Test
    void anExpiredOrderStillGetsPaidWithinTheGracePeriod() {
        SubscriptionOrder order = pendingOrder();
        order.setStatus(OrderStatus.EXPIRED);
        order.setExpiresAt(NOW.minusHours(5));
        givenOrder(order);

        assertThat(service.handleSepayWebhook(payload(208, "99000", MEMO))).isEqualTo(WebhookResult.ACTIVATED);
        assertThat(order.getStatus()).isEqualTo(OrderStatus.SUCCESS);
    }

    @Test
    void moneyArrivingAfterTheGracePeriodNeedsAnAdmin() {
        SubscriptionOrder order = pendingOrder();
        order.setStatus(OrderStatus.EXPIRED);
        order.setExpiresAt(NOW.minusHours(30));
        givenOrder(order);

        assertThat(service.handleSepayWebhook(payload(209, "99000", MEMO))).isEqualTo(WebhookResult.LATE);

        assertThat(order.getStatus()).isEqualTo(OrderStatus.NEEDS_REVIEW);
        assertThat(order.getPaidAmount()).isEqualByComparingTo("99000");
        assertThat(user.getSubscriptionPlan()).isNull();
    }

    @Test
    void moneyForACancelledOrderIsRecordedButNotActivated() {
        SubscriptionOrder order = pendingOrder();
        order.setStatus(OrderStatus.CANCELLED);
        givenOrder(order);

        assertThat(service.handleSepayWebhook(payload(210, "99000", MEMO))).isEqualTo(WebhookResult.LATE);

        assertThat(order.getStatus()).isEqualTo(OrderStatus.CANCELLED);
        assertThat(user.getSubscriptionPlan()).isNull();
    }

    @Test
    void aSecondTransferForAnAlreadyPaidOrderIsExtraMoneyAndNeverExtendsTheVipAgain() {
        SubscriptionOrder order = pendingOrder();
        givenOrder(order);
        service.handleSepayWebhook(payload(211, "99000", MEMO));
        LocalDateTime expiry = user.getVipExpiresAt();

        WebhookResult result = service.handleSepayWebhook(payload(212, "99000", MEMO));

        assertThat(result).isEqualTo(WebhookResult.EXTRA_PAYMENT);
        assertThat(user.getVipExpiresAt()).isEqualTo(expiry);
        assertThat(order.getPaidAmount()).isEqualByComparingTo("99000");
    }

    // ================================================================== admin duyệt tay

    @Test
    void adminConfirmActivatesAndRecordsWhoAndWhy() {
        SubscriptionOrder order = pendingOrder();
        order.setStatus(OrderStatus.NEEDS_REVIEW);
        givenOrder(order);

        SubscriptionOrderResponse response = service.adminConfirm(MEMO.toLowerCase(), 1L, "Khách bù tiền mặt");

        assertThat(response.getStatus()).isEqualTo(OrderStatus.SUCCESS);
        assertThat(order.getConfirmedBy()).isEqualTo(1L);
        assertThat(order.getNote()).isEqualTo("Khách bù tiền mặt");
        assertThat(order.getBankTransactionId()).isEqualTo("MANUAL:1");
        assertThat(user.getSubscriptionPlan()).isSameAs(monthly);
    }

    @Test
    void adminConfirmingAnAlreadyPaidOrderChangesNothing() {
        SubscriptionOrder order = pendingOrder();
        givenOrder(order);
        service.handleSepayWebhook(payload(300, "99000", MEMO));
        LocalDateTime expiry = user.getVipExpiresAt();

        service.adminConfirm(MEMO, 1L, "Duyệt lại");

        assertThat(user.getVipExpiresAt()).isEqualTo(expiry);
        assertThat(order.getConfirmedBy()).isNull();
    }

    @Test
    void adminCannotConfirmACancelledOrNonexistentOrder() {
        SubscriptionOrder cancelled = pendingOrder();
        cancelled.setStatus(OrderStatus.CANCELLED);
        givenOrder(cancelled);
        when(orderRepository.findByOrderCodeForUpdate("JLSPNOPE2222")).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.adminConfirm(MEMO, 1L, "x"))
                .isInstanceOfSatisfying(AppException.class, e -> assertThat(e.getStatus()).isEqualTo(400));
        assertThatThrownBy(() -> service.adminConfirm("JLSPNOPE2222", 1L, "x"))
                .isInstanceOf(ResourceNotFoundException.class);
        verify(userRepository, never()).save(any());
    }

    // ================================================================== hết hạn

    @Test
    void expiringOverdueOrdersUsesTheClock() {
        when(orderRepository.expirePendingBefore(NOW)).thenReturn(4);

        assertThat(service.expirePendingOrders()).isEqualTo(4);
        verify(orderRepository).expirePendingBefore(eq(NOW));
        verify(orderRepository, never()).findByOrderCodeForUpdate(anyString());
        verify(userRepository, never()).findByIdForUpdate(anyLong());
    }
}
