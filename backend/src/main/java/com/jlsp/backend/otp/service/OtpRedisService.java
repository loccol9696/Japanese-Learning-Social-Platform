package com.jlsp.backend.otp.service;

import com.jlsp.backend.common.exception.AppException;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.Duration;
import java.util.concurrent.TimeUnit;

/**
 * Sinh, lưu và kiểm tra mã OTP 6 số trong Redis, kèm giới hạn chống lạm dụng:
 * <ul>
 *   <li>mã sống {@value #OTP_TTL_MINUTES} phút;</li>
 *   <li>gửi lại cách nhau tối thiểu {@value #RESEND_COOLDOWN_SECONDS} giây, tối đa
 *       {@value #MAX_SENDS_PER_HOUR} lần/giờ cho mỗi email;</li>
 *   <li>nhập sai quá {@value #MAX_VERIFY_ATTEMPTS} lần thì mã bị huỷ.</li>
 * </ul>
 */
@Service
public class OtpRedisService {

    static final long OTP_TTL_MINUTES = 5;
    static final long RESEND_COOLDOWN_SECONDS = 60;
    static final int MAX_SENDS_PER_HOUR = 5;
    static final int MAX_VERIFY_ATTEMPTS = 5;

    private static final Duration OTP_TTL = Duration.ofMinutes(OTP_TTL_MINUTES);
    private static final SecureRandom RANDOM = new SecureRandom();

    private final StringRedisTemplate redis;

    public OtpRedisService(StringRedisTemplate redis) {
        this.redis = redis;
    }

    public long getOtpTtlMinutes() {
        return OTP_TTL_MINUTES;
    }

    /**
     * Tạo mã mới cho email (ghi đè mã cũ). Ném 429 nếu gửi quá nhanh/quá nhiều.
     */
    public String issue(OtpPurpose purpose, String email) {
        String cooldownKey = "otp:cooldown:" + purpose.key() + ":" + email;
        Long cooldownLeft = redis.getExpire(cooldownKey, TimeUnit.SECONDS);
        if (cooldownLeft != null && cooldownLeft > 0) {
            throw new AppException(429, "Vui lòng đợi " + cooldownLeft + " giây trước khi gửi lại mã");
        }

        String hourlyKey = "otp:hourly:" + email;
        Long sentThisHour = redis.opsForValue().increment(hourlyKey);
        if (sentThisHour != null && sentThisHour == 1) {
            redis.expire(hourlyKey, Duration.ofHours(1));
        }
        if (sentThisHour != null && sentThisHour > MAX_SENDS_PER_HOUR) {
            throw new AppException(429, "Bạn đã yêu cầu quá nhiều mã. Vui lòng thử lại sau 1 giờ");
        }

        String code = String.valueOf(100000 + RANDOM.nextInt(900000));
        redis.opsForValue().set(codeKey(purpose, email), code, OTP_TTL);
        redis.delete(attemptsKey(purpose, email));
        redis.opsForValue().set(cooldownKey, "1", Duration.ofSeconds(RESEND_COOLDOWN_SECONDS));
        return code;
    }

    /**
     * Kiểm tra mã; thành công thì mã bị xoá (chỉ dùng được một lần).
     */
    public void verify(OtpPurpose purpose, String email, String inputCode) {
        String codeKey = codeKey(purpose, email);
        String saved = redis.opsForValue().get(codeKey);
        if (saved == null) {
            throw new AppException(400, "Mã OTP không đúng hoặc đã hết hạn. Vui lòng yêu cầu mã mới");
        }

        String attemptsKey = attemptsKey(purpose, email);
        Long attempts = redis.opsForValue().increment(attemptsKey);
        if (attempts != null && attempts == 1) {
            redis.expire(attemptsKey, OTP_TTL);
        }
        if (attempts != null && attempts > MAX_VERIFY_ATTEMPTS) {
            redis.delete(codeKey);
            redis.delete(attemptsKey);
            throw new AppException(429, "Bạn đã nhập sai quá nhiều lần. Vui lòng yêu cầu mã mới");
        }

        if (!constantTimeEquals(saved, inputCode == null ? "" : inputCode.trim())) {
            long left = MAX_VERIFY_ATTEMPTS - (attempts == null ? 0 : attempts);
            throw new AppException(400, left > 0
                    ? "Mã OTP không đúng. Bạn còn " + left + " lần thử"
                    : "Mã OTP không đúng. Vui lòng yêu cầu mã mới");
        }

        redis.delete(codeKey);
        redis.delete(attemptsKey);
    }

    private static String codeKey(OtpPurpose purpose, String email) {
        return "otp:" + purpose.key() + ":" + email;
    }

    private static String attemptsKey(OtpPurpose purpose, String email) {
        return "otp:attempts:" + purpose.key() + ":" + email;
    }

    private static boolean constantTimeEquals(String a, String b) {
        return MessageDigest.isEqual(a.getBytes(StandardCharsets.UTF_8), b.getBytes(StandardCharsets.UTF_8));
    }
}
