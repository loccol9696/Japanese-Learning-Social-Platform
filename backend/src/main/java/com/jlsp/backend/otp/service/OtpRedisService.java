package com.jlsp.backend.otp.service;

import java.time.Duration;

import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.stereotype.Service;

import lombok.RequiredArgsConstructor;

@Service
@RequiredArgsConstructor
public class OtpRedisService {
    private final RedisTemplate<String, String> redisTemplate;
    private static final String OTP_PREFIX = "OTP:";
    private static final Duration OTP_EXPIRATION = Duration.ofMinutes(5);

    // Lưu mã OTP với thời gian sống tự hủy sau 5 phút
    public void saveOtp(String email, String otpCode) {
        String key = OTP_PREFIX + email;
        redisTemplate.opsForValue().set(key, otpCode, OTP_EXPIRATION);
    }

    // Lấy mã OTP hiện tại
    public String getOtp(String email) {
        return redisTemplate.opsForValue().get(OTP_PREFIX + email);
    }

    // Xóa mã OTP sau khi xác thực thành công
    public void deleteOtp(String email) {
        redisTemplate.delete(OTP_PREFIX + email);
    }

    // Kiểm tra tính hợp lệ của mã OTP
    public boolean validateOtp(String email, String inputOtp) {
        String savedOtp = getOtp(email);
        return savedOtp != null && savedOtp.equals(inputOtp);
    }
}
