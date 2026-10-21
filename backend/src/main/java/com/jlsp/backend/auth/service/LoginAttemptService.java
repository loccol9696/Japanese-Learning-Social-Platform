package com.jlsp.backend.auth.service;

import com.jlsp.backend.common.exception.AppException;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.util.Locale;
import java.util.concurrent.TimeUnit;

/**
 * Chống dò mật khẩu: sai {@value #MAX_FAILURES} lần liên tiếp với cùng một tài
 * khoản thì khoá đăng nhập {@value #LOCK_MINUTES} phút.
 */
@Service
public class LoginAttemptService {

    static final int MAX_FAILURES = 5;
    static final long LOCK_MINUTES = 15;

    private static final String PREFIX = "auth:login-fail:";

    private final StringRedisTemplate redis;

    public LoginAttemptService(StringRedisTemplate redis) {
        this.redis = redis;
    }

    public void ensureNotLocked(String identifier) {
        String value = redis.opsForValue().get(key(identifier));
        if (value != null && Long.parseLong(value) >= MAX_FAILURES) {
            Long secondsLeft = redis.getExpire(key(identifier), TimeUnit.SECONDS);
            long minutes = secondsLeft == null || secondsLeft <= 0 ? LOCK_MINUTES : (secondsLeft + 59) / 60;
            throw new AppException(429,
                    "Bạn đã đăng nhập sai quá nhiều lần. Vui lòng thử lại sau " + minutes + " phút");
        }
    }

    public void recordFailure(String identifier) {
        String key = key(identifier);
        Long count = redis.opsForValue().increment(key);
        if (count != null && count == 1) {
            redis.expire(key, Duration.ofMinutes(LOCK_MINUTES));
        }
    }

    public void reset(String identifier) {
        redis.delete(key(identifier));
    }

    private static String key(String identifier) {
        return PREFIX + identifier.trim().toLowerCase(Locale.ROOT);
    }
}
