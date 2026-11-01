package com.jlsp.backend.otp.service;

/** Mục đích của mã OTP — mỗi mục đích có khoá Redis riêng, không dùng chéo được. */
public enum OtpPurpose {
    VERIFY_EMAIL("verify", "Xác thực tài khoản JLSP",
            "Mã xác thực tài khoản của bạn là: %s"),
    RESET_PASSWORD("reset", "Đặt lại mật khẩu JLSP",
            "Mã đặt lại mật khẩu của bạn là: %s\nNếu bạn không yêu cầu đặt lại mật khẩu, hãy bỏ qua email này.");

    private final String key;
    private final String emailSubject;
    private final String emailBodyTemplate;

    OtpPurpose(String key, String emailSubject, String emailBodyTemplate) {
        this.key = key;
        this.emailSubject = emailSubject;
        this.emailBodyTemplate = emailBodyTemplate;
    }

    public String key() {
        return key;
    }

    public String emailSubject() {
        return emailSubject;
    }

    public String emailBody(String code, long validMinutes) {
        return String.format(emailBodyTemplate, code)
                + "\nMã có hiệu lực trong " + validMinutes + " phút. Vui lòng không chia sẻ mã này với bất kỳ ai.";
    }
}
