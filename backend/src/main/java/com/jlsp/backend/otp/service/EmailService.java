package com.jlsp.backend.otp.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.mail.MailException;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.stereotype.Service;

@Service
public class EmailService {

    private static final Logger log = LoggerFactory.getLogger(EmailService.class);

    private final JavaMailSender javaMailSender;

    public EmailService(JavaMailSender javaMailSender) {
        this.javaMailSender = javaMailSender;
    }

    /**
     * Gửi mã OTP. Trả về false (không ném lỗi) nếu gửi thất bại để luồng gọi tự
     * quyết định — người dùng luôn có thể bấm "Gửi lại mã".
     */
    public boolean sendOtpEmail(String toEmail, String otpCode, OtpPurpose purpose, long validMinutes) {
        SimpleMailMessage message = new SimpleMailMessage();
        message.setTo(toEmail);
        message.setSubject(purpose.emailSubject());
        message.setText(purpose.emailBody(otpCode, validMinutes));
        try {
            javaMailSender.send(message);
            return true;
        } catch (MailException e) {
            log.error("Gửi email OTP ({}) tới {} thất bại: {}", purpose, toEmail, e.getMessage());
            return false;
        }
    }

    /** Báo tài khoản đã bị khóa kèm lý do. Trả về false (không ném lỗi) nếu gửi thất bại: việc khóa vẫn có hiệu lực. */
    public boolean sendAccountLockedEmail(String toEmail, String name, String reason) {
        SimpleMailMessage message = new SimpleMailMessage();
        message.setTo(toEmail);
        message.setSubject("Tài khoản của bạn đã bị khóa");
        message.setText("Xin chào " + name + ",\n\n"
                + "Tài khoản của bạn đã bị khóa do vi phạm tiêu chuẩn cộng đồng.\n"
                + "Lý do: " + reason + "\n\n"
                + "Bạn sẽ không thể đăng nhập cho đến khi tài khoản được mở khóa.");
        try {
            javaMailSender.send(message);
            return true;
        } catch (MailException e) {
            log.error("Gửi email khóa tài khoản tới {} thất bại: {}", toEmail, e.getMessage());
            return false;
        }
    }
}
