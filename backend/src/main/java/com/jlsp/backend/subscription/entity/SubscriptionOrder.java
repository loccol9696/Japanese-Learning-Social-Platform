package com.jlsp.backend.subscription.entity;

import com.jlsp.backend.user.entity.User;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Entity
@Table(name = "subscription_orders")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class SubscriptionOrder {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "order_code", nullable = false, unique = true, length = 50)
    private String orderCode; // Mã giao dịch (vd: TX-98421)

    /**
     * Mã xác nhận giao dịch hiển thị nổi bật dưới mã QR (vd: JLSP-84920)
     */
    @Column(name = "verification_code", unique = true, length = 50)
    private String verificationCode; // chỉ còn ở đơn cũ (mô phỏng QR); đơn mới dùng transferMemo

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "plan_id", nullable = false)
    private SubscriptionPlan plan;

    @Column(nullable = false)
    private BigDecimal amount;

    @Column(name = "payment_method", nullable = false, length = 50)
    @Builder.Default
    private String paymentMethod = "VIETQR_LOCAL";

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    @Builder.Default
    private OrderStatus status = OrderStatus.PENDING;

    @Column(name = "qr_url", columnDefinition = "TEXT")
    private String qrUrl;

    /** Nội dung chuyển khoản người dùng phải ghi (cũng là mã đơn), vd JLSP7K3Q9M2X; ngân hàng khớp tiền theo mã này. */
    @Column(name = "transfer_memo", unique = true, length = 32)
    private String transferMemo;

    /** Hết hạn thanh toán; sau mốc này đơn chuyển EXPIRED nhưng tiền về muộn trong thời gian ân hạn vẫn được nhận. */
    @Column(name = "expires_at")
    private LocalDateTime expiresAt;

    /** Tổng số tiền đã nhận cho đơn này (có thể gom nhiều lần chuyển khoản). */
    @Column(name = "paid_amount")
    private BigDecimal paidAmount;

    /** Mã giao dịch ngân hàng (SePay) đã kích hoạt đơn, hoặc MANUAL:<adminId> khi admin duyệt tay. */
    @Column(name = "bank_transaction_id", length = 64)
    private String bankTransactionId;

    /** Admin đã duyệt tay đơn này (null nếu kích hoạt tự động) và ghi chú lý do. */
    @Column(name = "confirmed_by")
    private Long confirmedBy;

    @Column(name = "note", length = 255)
    private String note;

    /** Khoá lạc quan: hai lần xử lý đồng thời cùng một đơn không thể cùng thắng. */
    @Version
    @Column(name = "version", nullable = false, columnDefinition = "bigint default 0 not null")
    private Long version;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "completed_at")
    private LocalDateTime completedAt;

    public enum OrderStatus {
        PENDING,
        SUCCESS,
        FAILED,
        /** Quá hạn thanh toán, chưa nhận được đủ tiền. */
        EXPIRED,
        CANCELLED,
        /** Đã nhận tiền nhưng chưa đủ hoặc về quá muộn: admin xem xét thủ công. */
        NEEDS_REVIEW
    }

    @PrePersist
    protected void onCreate() {
        this.createdAt = LocalDateTime.now();
        if (this.status == null) {
            this.status = OrderStatus.PENDING;
        }
        if (this.paymentMethod == null) {
            this.paymentMethod = "VIETQR_LOCAL";
        }
    }
}
