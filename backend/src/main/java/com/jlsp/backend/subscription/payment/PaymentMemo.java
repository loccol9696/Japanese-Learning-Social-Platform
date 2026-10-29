package com.jlsp.backend.subscription.payment;

import java.security.SecureRandom;
import java.util.Locale;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Mã chuyển khoản (đồng thời là mã đơn): {@code JLSP} + 8 ký tự ngẫu nhiên. Chỉ gồm chữ và số vì ngân hàng thường bỏ
 * dấu gạch, khoảng trắng hoặc đổi chữ hoa/thường trong nội dung chuyển khoản.
 */
public final class PaymentMemo {

    public static final String PREFIX = "JLSP";
    private static final int RANDOM_LENGTH = 8;
    /** Bỏ các ký tự dễ nhầm (0/O, 1/I) để người dùng gõ tay không sai. */
    private static final String ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    private static final SecureRandom RANDOM = new SecureRandom();
    private static final Pattern MEMO = Pattern.compile(PREFIX + "[" + ALPHABET + "]{" + RANDOM_LENGTH + "}");

    private PaymentMemo() {
    }

    public static String generate() {
        StringBuilder sb = new StringBuilder(PREFIX);
        for (int i = 0; i < RANDOM_LENGTH; i++) {
            sb.append(ALPHABET.charAt(RANDOM.nextInt(ALPHABET.length())));
        }
        return sb.toString();
    }

    /**
     * Tìm mã chuyển khoản trong các trường của giao dịch. Chuẩn hóa bằng cách viết hoa và bỏ mọi ký tự không phải
     * chữ/số trước khi tìm, nên "jlsp 7k3q-9m2x" hay "JLSP7K3Q9M2X" đều cho cùng kết quả.
     *
     * @return mã (đã chuẩn hóa) hoặc null nếu không có
     */
    public static String extract(String... fields) {
        for (String field : fields) {
            if (field == null) {
                continue;
            }
            String normalized = field.toUpperCase(Locale.ROOT).replaceAll("[^A-Z0-9]", "");
            Matcher matcher = MEMO.matcher(normalized);
            if (matcher.find()) {
                return matcher.group();
            }
        }
        return null;
    }
}
