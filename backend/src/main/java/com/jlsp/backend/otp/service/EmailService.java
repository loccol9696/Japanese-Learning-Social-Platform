package com.jlsp.backend.otp.service;

import java.security.SecureRandom;

import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.stereotype.Service;

import lombok.RequiredArgsConstructor;

@Service
@RequiredArgsConstructor
public class EmailService {

    private final JavaMailSender javaMailSender;

    public String generateOtp() {
        SecureRandom random = new SecureRandom();
        int code = 100000 + random.nextInt(900000); // 6 rand dig
        return String.valueOf(code);
    }

    public void sendOtpEmail(String toEmail, String otpCode) {
        SimpleMailMessage message = new SimpleMailMessage();
        message.setTo(toEmail);
        message.setSubject("OTP Verification - JLSP");
        message.setText("Your OTP is: " + otpCode
                + "\n The OTP is valid for 5 minutes. Please do not share it with anyone");

        javaMailSender.send(message);
    }
}
