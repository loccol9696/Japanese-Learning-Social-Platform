package com.jlsp.backend.subscription.entity;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * Sổ cái giao dịch ngân hàng nhận từ cổng thanh toán (SePay). Mỗi giao dịch được ghi đúng một lần nhờ ràng buộc
 * duy nhất (gateway, external_id): webhook bị gửi lại không bao giờ kích hoạt gói hai lần, và có dữ liệu để đối soát.
 */
@Entity
@Table(name = "payment_transactions",
        uniqueConstraints = @UniqueConstraint(name = "uk_payment_tx_gateway_external",
                columnNames = {"gateway", "external_id"}))
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class PaymentTransaction {

    public static final String GATEWAY_SEPAY = "SEPAY";

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 20)
    private String gateway;

    /** Mã giao dịch do cổng thanh toán cấp. */
    @Column(name = "external_id", nullable = false, length = 64)
    private String externalId;

    @Column(nullable = false, precision = 18, scale = 2)
    private BigDecimal amount;

    @Column(name = "account_number", length = 32)
    private String accountNumber;

    @Column(columnDefinition = "TEXT")
    private String content;

    @Column(name = "reference_code", length = 64)
    private String referenceCode;

    /** Thời điểm giao dịch theo ngân hàng (chuỗi gốc từ cổng, không phân tích lại). */
    @Column(name = "transaction_time", length = 32)
    private String transactionTime;

    /** Đơn được khớp (nếu có). */
    @Column(name = "order_id")
    private Long orderId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private Status status;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    public enum Status {
        /** Không tìm thấy mã đơn trong nội dung hoặc không có đơn tương ứng. */
        UNMATCHED,
        /** Đủ tiền, đã kích hoạt gói. */
        MATCHED,
        /** Chưa đủ tiền cho đơn (đã cộng dồn vào đơn, chờ chuyển thêm hoặc admin xử lý). */
        UNDERPAID,
        /** Về quá muộn hoặc đơn đã hủy: cần admin xem xét. */
        LATE,
        /** Đơn đã thanh toán trước đó: tiền thừa, cần hoàn lại. */
        EXTRA_PAYMENT
    }

    @PrePersist
    protected void onCreate() {
        this.createdAt = LocalDateTime.now();
    }
}
