package com.jlsp.backend.common.security.token;

import com.jlsp.backend.common.exception.AppException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
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
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

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

    private static final Logger log = LoggerFactory.getLogger(RefreshTokenService.class);
    private static final String TOKEN_PREFIX = "auth:rt:";
    private static final String USER_PREFIX = "auth:rt:user:";
    private static final SecureRandom RANDOM = new SecureRandom();

    private final StringRedisTemplate redis;
    private final Duration refreshTokenTtl;
    private final AccessTokenDenylist accessTokenDenylist;
    private final Map<String, String> inMemoryTokens = new ConcurrentHashMap<>();

    public RefreshTokenService(StringRedisTemplate redis,
                               @Value("${jwt.refresh-token-ttl:P14D}") Duration refreshTokenTtl,
                               AccessTokenDenylist accessTokenDenylist) {
        this.redis = redis;
        this.refreshTokenTtl = refreshTokenTtl;
        this.accessTokenDenylist = accessTokenDenylist;
    }

    public Duration getRefreshTokenTtl() {
        return refreshTokenTtl;
    }

    public String issue(Long userId) {
        byte[] bytes = new byte[32];
        RANDOM.nextBytes(bytes);
        String token = Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
        String hash = hash(token);

        try {
            redis.opsForValue().set(TOKEN_PREFIX + hash, String.valueOf(userId), refreshTokenTtl);
            String userKey = USER_PREFIX + userId;
            redis.opsForSet().add(userKey, hash);
            redis.expire(userKey, refreshTokenTtl);
        } catch (RuntimeException e) {
            log.warn("Redis không khả dụng khi cấp refresh token, chuyển sang in-memory fallback: {}", e.getMessage());
            inMemoryTokens.put(TOKEN_PREFIX + hash, String.valueOf(userId));
        }
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
        String userId = null;
        try {
            userId = redis.opsForValue().getAndDelete(TOKEN_PREFIX + hash);
            if (userId != null) {
                redis.opsForSet().remove(USER_PREFIX + userId, hash);
            }
        } catch (RuntimeException e) {
            log.warn("Redis không khả dụng khi consume refresh token, tra cứu in-memory fallback: {}", e.getMessage());
            userId = inMemoryTokens.remove(TOKEN_PREFIX + hash);
        }
        if (userId == null) {
            userId = inMemoryTokens.remove(TOKEN_PREFIX + hash);
        }
        if (userId == null) {
            throw invalid();
        }
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
        try {
            String userId = redis.opsForValue().getAndDelete(TOKEN_PREFIX + hash);
            if (userId != null) {
                redis.opsForSet().remove(USER_PREFIX + userId, hash);
            }
        } catch (RuntimeException e) {
            inMemoryTokens.remove(TOKEN_PREFIX + hash);
        }
    }

    /**
     * Thu hồi mọi phiên của người dùng (đổi / đặt lại mật khẩu, khoá tài khoản): xoá toàn bộ refresh
     * token và vô hiệu hoá luôn các access token đã cấp, nên thiết bị khác bị đăng xuất ngay thay vì
     * còn dùng được tới khi access token hết hạn.
     */
    public void revokeAll(Long userId) {
        try {
            accessTokenDenylist.revokeUserTokens(userId);
            String userKey = USER_PREFIX + userId;
            Set<String> hashes = redis.opsForSet().members(userKey);
            if (hashes != null) {
                for (String hash : hashes) {
                    redis.delete(TOKEN_PREFIX + hash);
                }
            }
            redis.delete(userKey);
        } catch (RuntimeException e) {
            log.warn("Redis không khả dụng khi revokeAll: {}", e.getMessage());
        }
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
