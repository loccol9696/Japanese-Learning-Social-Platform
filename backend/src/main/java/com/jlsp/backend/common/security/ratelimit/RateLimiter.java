package com.jlsp.backend.common.security.ratelimit;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.util.concurrent.TimeUnit;

/**
 * Giới hạn tần suất theo cửa sổ cố định, đếm trong Redis nên dùng chung được giữa nhiều instance.
 * Redis lỗi thì cho qua (fail-open): giới hạn chỉ là lớp phòng vệ phụ, không được làm sập đăng nhập.
 */
@Service
public class RateLimiter {

    private static final Logger log = LoggerFactory.getLogger(RateLimiter.class);
    private static final String PREFIX = "ratelimit:";

    /** Kết quả một lần xin phép; {@code retryAfterSeconds} chỉ có nghĩa khi bị từ chối. */
    public record Decision(boolean allowed, long retryAfterSeconds) {
        public static final Decision ALLOWED = new Decision(true, 0);
    }

    private final StringRedisTemplate redis;

    public RateLimiter(StringRedisTemplate redis) {
        this.redis = redis;
    }

    /**
     * Tính một lượt cho {@code key}; từ lượt thứ {@code maxRequests + 1} trong cùng cửa sổ
     * {@code window} thì bị từ chối cho tới khi cửa sổ kết thúc.
     */
    public Decision tryAcquire(String key, int maxRequests, Duration window) {
        String redisKey = PREFIX + key;
        try {
            Long count = redis.opsForValue().increment(redisKey);
            if (count == null) {
                return Decision.ALLOWED;
            }
            if (count == 1) {
                redis.expire(redisKey, window);
            }
            if (count <= maxRequests) {
                return Decision.ALLOWED;
            }
            Long ttl = redis.getExpire(redisKey, TimeUnit.SECONDS);
            if (ttl == null || ttl < 0) {
                // Khoá mất TTL (tiến trình chết giữa INCR và EXPIRE): đặt lại để không chặn vĩnh viễn.
                redis.expire(redisKey, window);
                ttl = window.toSeconds();
            }
            return new Decision(false, Math.max(1, ttl));
        } catch (RuntimeException e) {
            log.warn("Không kiểm tra được giới hạn tần suất cho {}: {}", key, e.getMessage());
            return Decision.ALLOWED;
        }
    }
}
