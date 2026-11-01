package com.jlsp.backend.subscription.payment;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;

/**
 * Cấu hình thanh toán chuyển khoản (VietQR + SePay). Mọi giá trị đến từ biến môi trường, không ghi cứng trong code.
 * Thiếu thông tin ngân hàng thì không tạo được đơn; thiếu khoá webhook thì webhook từ chối mọi yêu cầu.
 */
@Component
public class PaymentProperties {

    private final boolean enabled;
    private final String bankBin;
    private final String bankName;
    private final String accountNo;
    private final String accountName;
    private final int orderTtlMinutes;
    private final int lateGraceHours;
    private final int maxOrdersPerHour;
    private final String webhookKey;

    public PaymentProperties(
            @Value("${payment.enabled:true}") boolean enabled,
            @Value("${payment.bank-bin:}") String bankBin,
            @Value("${payment.bank-name:}") String bankName,
            @Value("${payment.account-no:}") String accountNo,
            @Value("${payment.account-name:}") String accountName,
            @Value("${payment.order-ttl-minutes:15}") int orderTtlMinutes,
            @Value("${payment.late-grace-hours:24}") int lateGraceHours,
            @Value("${payment.max-orders-per-hour:10}") int maxOrdersPerHour,
            @Value("${sepay.webhook-key:}") String webhookKey) {
        this.enabled = enabled;
        this.bankBin = bankBin == null ? "" : bankBin.trim();
        this.bankName = bankName == null ? "" : bankName.trim();
        this.accountNo = accountNo == null ? "" : accountNo.trim();
        this.accountName = accountName == null ? "" : accountName.trim();
        this.orderTtlMinutes = Math.max(1, orderTtlMinutes);
        this.lateGraceHours = Math.max(0, lateGraceHours);
        this.maxOrdersPerHour = Math.max(1, maxOrdersPerHour);
        this.webhookKey = webhookKey == null ? "" : webhookKey.trim();
    }

    /** Đã bật và có đủ thông tin tài khoản nhận tiền. */
    public boolean canCreateOrders() {
        return enabled && !bankBin.isEmpty() && !accountNo.isEmpty() && !accountName.isEmpty();
    }

    /** So khớp khoá webhook trong thời gian không đổi; chưa cấu hình khoá thì từ chối tất cả. */
    public boolean webhookKeyMatches(String presented) {
        if (webhookKey.isEmpty() || presented == null) {
            return false;
        }
        return MessageDigest.isEqual(
                webhookKey.getBytes(StandardCharsets.UTF_8), presented.getBytes(StandardCharsets.UTF_8));
    }

    public boolean enabled() {
        return enabled;
    }

    public String bankBin() {
        return bankBin;
    }

    public String bankName() {
        return bankName;
    }

    public String accountNo() {
        return accountNo;
    }

    public String accountName() {
        return accountName;
    }

    public int orderTtlMinutes() {
        return orderTtlMinutes;
    }

    public int lateGraceHours() {
        return lateGraceHours;
    }

    public int maxOrdersPerHour() {
        return maxOrdersPerHour;
    }
}
