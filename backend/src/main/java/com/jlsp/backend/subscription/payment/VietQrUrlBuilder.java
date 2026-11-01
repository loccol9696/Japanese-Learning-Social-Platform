package com.jlsp.backend.subscription.payment;

import java.math.BigDecimal;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;

/**
 * Dựng link ảnh mã QR VietQR (chuẩn Napas 247) có sẵn số tiền và nội dung chuyển khoản. Dịch vụ img.vietqr.io chỉ còn
 * trả ảnh SVG (đuôi .png / .jpg chuyển hướng sang .svg), nên link dùng thẳng .svg và app phải vẽ được SVG.
 */
public final class VietQrUrlBuilder {

    private static final String BASE = "https://img.vietqr.io/image/";

    private VietQrUrlBuilder() {
    }

    public static String build(PaymentProperties props, BigDecimal amount, String memo) {
        return BASE + props.bankBin() + "-" + props.accountNo() + "-qr_only.svg"
                + "?amount=" + amount.setScale(0, java.math.RoundingMode.HALF_UP).toPlainString()
                + "&addInfo=" + encode(memo)
                + "&accountName=" + encode(props.accountName());
    }

    private static String encode(String value) {
        // URLEncoder đổi khoảng trắng thành '+', còn VietQR cần %20.
        return URLEncoder.encode(value, StandardCharsets.UTF_8).replace("+", "%20");
    }
}
