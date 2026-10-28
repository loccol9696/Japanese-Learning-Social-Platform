package com.jlsp.backend.auth.service;

import com.jlsp.backend.common.exception.AppException;
import org.springframework.dao.DataAccessException;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.util.Locale;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.TimeUnit;

/**
 * Chống dò mật khẩu: sai {@value #MAX_FAILURES} lần liên tiếp với cùng một tài
 * khoản thì khoá đăng nhập {@value #LOCK_MINUTES} phút.
 */
@Service
public class LoginAttemptService {

    static final int MAX_FAILURES = 5;
    static final long LOCK_MINUTES = 15;
    private static final long CIRCUIT_BREAKER_MS = 300_000L;

    private static final String PREFIX = "auth:login-fail:";

    private final StringRedisTemplate redis;
    private final Map<String, Integer> fallbackFailures = new ConcurrentHashMap<>();
    private volatile long redisDownUntilMs = 0L;

    public LoginAttemptService(StringRedisTemplate redis) {
        this.redis = redis;
    }

    public void ensureNotLocked(String identifier) {
        String k = key(identifier);
        if (System.currentTimeMillis() < redisDownUntilMs) {
            checkFallbackLock(k);
            return;
        }
        try {
            String value = redis.opsForValue().get(k);
            if (value != null && Long.parseLong(value) >= MAX_FAILURES) {
                Long secondsLeft = redis.getExpire(k, TimeUnit.SECONDS);
                long minutes = secondsLeft == null || secondsLeft <= 0 ? LOCK_MINUTES : (secondsLeft + 59) / 60;
                throw new AppException(429,
                        "Bạn đã đăng nhập sai quá nhiều lần. Vui lòng thử lại sau " + minutes + " phút");
            }
        } catch (DataAccessException e) {
            redisDownUntilMs = System.currentTimeMillis() + CIRCUIT_BREAKER_MS;
            checkFallbackLock(k);
        }
    }

    private void checkFallbackLock(String k) {
        int count = fallbackFailures.getOrDefault(k, 0);
        if (count >= MAX_FAILURES) {
            throw new AppException(429,
                    "Bạn đã đăng nhập sai quá nhiều lần. Vui lòng thử lại sau " + LOCK_MINUTES + " phút");
        }
    }

    public void recordFailure(String identifier) {
        String key = key(identifier);
        fallbackFailures.merge(key, 1, Integer::sum);
        if (System.currentTimeMillis() < redisDownUntilMs) {
            return;
        }
        try {
            Long count = redis.opsForValue().increment(key);
            if (count != null && count == 1) {
                redis.expire(key, Duration.ofMinutes(LOCK_MINUTES));
            }
        } catch (DataAccessException e) {
            redisDownUntilMs = System.currentTimeMillis() + CIRCUIT_BREAKER_MS;
        }
    }

    public void reset(String identifier) {
        String key = key(identifier);
        fallbackFailures.remove(key);
        if (System.currentTimeMillis() < redisDownUntilMs) {
            return;
        }
        try {
            redis.delete(key);
        } catch (DataAccessException e) {
            redisDownUntilMs = System.currentTimeMillis() + CIRCUIT_BREAKER_MS;
        }
    }

    private static String key(String identifier) {
        return PREFIX + identifier.trim().toLowerCase(Locale.ROOT);
    }
}
