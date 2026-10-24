package com.jlsp.backend.common.security.token;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.time.Instant;

/**
 * Danh sách access token đã bị thu hồi (đăng xuất) trước khi hết hạn.
 * Khoá tự hết hạn cùng lúc với token nên không phình to.
 */
@Service
public class AccessTokenDenylist {

    private static final Logger log = LoggerFactory.getLogger(AccessTokenDenylist.class);
    private static final String PREFIX = "auth:deny:";

    private final StringRedisTemplate redis;

    public AccessTokenDenylist(StringRedisTemplate redis) {
        this.redis = redis;
    }

    public void deny(String tokenId, Instant expiresAt) {
        Duration ttl = Duration.between(Instant.now(), expiresAt);
        if (tokenId == null || ttl.isNegative() || ttl.isZero()) {
            return;
        }
        redis.opsForValue().set(PREFIX + tokenId, "1", ttl);
    }

    /**
     * Redis lỗi thì coi như chưa bị thu hồi (fail-open) để cả hệ thống không sập
     * theo Redis; access token vẫn tự hết hạn sau thời gian ngắn.
     */
    public boolean isDenied(String tokenId) {
        try {
            return Boolean.TRUE.equals(redis.hasKey(PREFIX + tokenId));
        } catch (RuntimeException e) {
            log.warn("Không kiểm tra được access token denylist: {}", e.getMessage());
            return false;
        }
    }
}
