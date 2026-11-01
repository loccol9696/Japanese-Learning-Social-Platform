package com.jlsp.backend.subscription.payment;

/** Kết quả xử lý một webhook tiền vào; mọi kết quả đều trả 200 cho cổng thanh toán (đã nhận, không cần gửi lại). */
public enum WebhookResult {
    /** Không phải tiền vào, sai tài khoản nhận hoặc thiếu dữ liệu: bỏ qua. */
    IGNORED,
    /** Giao dịch này đã xử lý trước đó (webhook bị gửi lại). */
    DUPLICATE,
    /** Không tìm thấy mã đơn trong nội dung chuyển khoản. */
    UNMATCHED,
    /** Đủ tiền, đã kích hoạt gói. */
    ACTIVATED,
    /** Chưa đủ tiền: đã cộng dồn vào đơn. */
    UNDERPAID,
    /** Về quá muộn hoặc đơn đã hủy: chờ admin xem xét. */
    LATE,
    /** Đơn đã thanh toán trước đó: tiền thừa. */
    EXTRA_PAYMENT
}
