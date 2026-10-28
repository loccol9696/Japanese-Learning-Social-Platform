package com.jlsp.backend.common.security.token;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataAccessException;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.time.Instant;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Danh sách access token đã bị thu hồi (đăng xuất) trước khi hết hạn.
 * Khoá tự hết hạn cùng lúc với token nên không phình to.
 */
@Service
public class AccessTokenDenylist {

    private static final Logger log = LoggerFactory.getLogger(AccessTokenDenylist.class);
    private static final String PREFIX = "auth:deny:";
    private static final long CIRCUIT_BREAKER_MS = 300_000L;

    private final StringRedisTemplate redis;
    private final Map<String, Instant> fallbackDenied = new ConcurrentHashMap<>();
    private volatile long redisDownUntilMs = 0L;

    public AccessTokenDenylist(StringRedisTemplate redis) {
        this.redis = redis;
    }

    public void deny(String tokenId, Instant expiresAt) {
        Duration ttl = Duration.between(Instant.now(), expiresAt);
        if (tokenId == null || ttl.isNegative() || ttl.isZero()) {
            return;
        }
        fallbackDenied.put(tokenId, expiresAt);
        if (System.currentTimeMillis() < redisDownUntilMs) {
            return;
        }
        try {
            redis.opsForValue().set(PREFIX + tokenId, "1", ttl);
        } catch (DataAccessException e) {
            redisDownUntilMs = System.currentTimeMillis() + CIRCUIT_BREAKER_MS;
        }
    }

    /**
     * Redis lỗi thì coi như chưa bị thu hồi (fail-open) để cả hệ thống không sập
     * theo Redis; access token vẫn tự hết hạn sau thời gian ngắn.
     */
    public boolean isDenied(String tokenId) {
        if (System.currentTimeMillis() < redisDownUntilMs) {
            return isFallbackDenied(tokenId);
        }
        try {
            return Boolean.TRUE.equals(redis.hasKey(PREFIX + tokenId));
        } catch (RuntimeException e) {
            redisDownUntilMs = System.currentTimeMillis() + CIRCUIT_BREAKER_MS;
            log.warn("Không kiểm tra được access token denylist (chuyển sang RAM 5 phút): {}", e.getMessage());
            return isFallbackDenied(tokenId);
        }
    }

    private boolean isFallbackDenied(String tokenId) {
        if (tokenId == null) return false;
        Instant exp = fallbackDenied.get(tokenId);
        if (exp != null) {
            if (exp.isAfter(Instant.now())) {
                return true;
            }
            fallbackDenied.remove(tokenId);
        }
        return false;
    }
}
