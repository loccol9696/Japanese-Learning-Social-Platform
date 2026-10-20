package com.jlsp.backend.common.security.token;

import com.jlsp.backend.common.exception.AppException;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.Duration;
import java.util.Base64;
import java.util.HexFormat;
import java.util.Set;

/**
 * Refresh token dạng chuỗi ngẫu nhiên (không phải JWT), lưu trong Redis dưới dạng
 * băm SHA-256 — lộ Redis cũng không dùng được token. Mỗi thiết bị một token;
 * token được đổi mới (rotate) mỗi lần dùng.
 *
 * <pre>
 * auth:rt:{hash}        -> userId   (TTL = refresh-token-ttl)
 * auth:rt:user:{userId} -> {hash...} (để thu hồi toàn bộ khi đổi mật khẩu)
 * </pre>
 */
@Service
public class RefreshTokenService {

    private static final String TOKEN_PREFIX = "auth:rt:";
    private static final String USER_PREFIX = "auth:rt:user:";
    private static final SecureRandom RANDOM = new SecureRandom();

    private final StringRedisTemplate redis;
    private final Duration refreshTokenTtl;

    public RefreshTokenService(StringRedisTemplate redis,
                               @Value("${jwt.refresh-token-ttl:P14D}") Duration refreshTokenTtl) {
        this.redis = redis;
        this.refreshTokenTtl = refreshTokenTtl;
    }

    public Duration getRefreshTokenTtl() {
        return refreshTokenTtl;
    }

    public String issue(Long userId) {
        byte[] bytes = new byte[32];
        RANDOM.nextBytes(bytes);
        String token = Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
        String hash = hash(token);

        redis.opsForValue().set(TOKEN_PREFIX + hash, String.valueOf(userId), refreshTokenTtl);
        String userKey = USER_PREFIX + userId;
        redis.opsForSet().add(userKey, hash);
        redis.expire(userKey, refreshTokenTtl);
        return token;
    }

    /**
     * Dùng refresh token một lần: xoá ngay (chống dùng lại) và trả về userId.
     * Ném 401 nếu token không tồn tại / hết hạn / đã dùng.
     */
    public Long consume(String token) {
        if (token == null || token.isBlank()) {
            throw invalid();
        }
        String hash = hash(token);
        String userId = redis.opsForValue().getAndDelete(TOKEN_PREFIX + hash);
        if (userId == null) {
            throw invalid();
        }
        redis.opsForSet().remove(USER_PREFIX + userId, hash);
        try {
            return Long.valueOf(userId);
        } catch (NumberFormatException e) {
            throw invalid();
        }
    }

    public void revoke(String token) {
        if (token == null || token.isBlank()) {
            return;
        }
        String hash = hash(token);
        String userId = redis.opsForValue().getAndDelete(TOKEN_PREFIX + hash);
        if (userId != null) {
            redis.opsForSet().remove(USER_PREFIX + userId, hash);
        }
    }

    /** Thu hồi mọi phiên của người dùng (đổi / đặt lại mật khẩu, khoá tài khoản). */
    public void revokeAll(Long userId) {
        String userKey = USER_PREFIX + userId;
        Set<String> hashes = redis.opsForSet().members(userKey);
        if (hashes != null) {
            for (String hash : hashes) {
                redis.delete(TOKEN_PREFIX + hash);
            }
        }
        redis.delete(userKey);
    }

    private static AppException invalid() {
        return new AppException(401, "Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại");
    }

    static String hash(String token) {
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256")
                    .digest(token.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(digest);
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 không khả dụng", e);
        }
    }
}
