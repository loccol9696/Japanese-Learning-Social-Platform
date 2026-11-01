package com.jlsp.backend.subscription.service;

import com.jlsp.backend.common.response.PageResponse;
import com.jlsp.backend.subscription.dto.request.CreateOrderRequest;
import com.jlsp.backend.subscription.dto.request.SepayWebhookPayload;
import com.jlsp.backend.subscription.dto.response.SubscriptionOrderResponse;
import com.jlsp.backend.subscription.entity.SubscriptionOrder;
import com.jlsp.backend.subscription.payment.WebhookResult;
import org.springframework.data.domain.Pageable;

/**
 * Thanh toán mua gói bằng chuyển khoản VietQR. Chỉ có hai đường làm một đơn thành công: webhook ngân hàng đã được xác
 * thực (đủ tiền, đúng mã chuyển khoản) hoặc admin duyệt tay có ghi lý do.
 */
public interface PaymentService {

    /** Tạo đơn (hoặc mở lại đơn chờ còn hạn cho cùng gói) cho người dùng đang đăng nhập. */
    SubscriptionOrderResponse createOrder(Long userId, CreateOrderRequest request);

    /** Xem một đơn; chỉ chủ đơn xem được, đơn của người khác coi như không tồn tại. */
    SubscriptionOrderResponse getMyOrder(Long userId, String orderCode);

    PageResponse<SubscriptionOrderResponse> getMyOrders(Long userId, Pageable pageable);

    /** Toàn bộ đơn cho admin. */
    PageResponse<SubscriptionOrderResponse> getAllOrders(SubscriptionOrder.OrderStatus status, Pageable pageable);

    /** Admin duyệt tay một đơn chưa thành công (bắt buộc có ghi chú). */
    SubscriptionOrderResponse adminConfirm(String orderCode, Long adminId, String note);

    /** Xử lý một webhook tiền vào từ SePay (đã xác thực khoá ở controller). */
    WebhookResult handleSepayWebhook(SepayWebhookPayload payload);

    /** Chuyển các đơn chờ đã quá hạn sang EXPIRED; trả số đơn đã chuyển. */
    int expirePendingOrders();
}
