package com.jlsp.backend.common.security.token;

import com.jlsp.backend.common.security.jwt.JwtUtils.AccessTokenClaims;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.time.Instant;

/**
 * Danh sách access token đã bị thu hồi trước khi hết hạn. Khoá tự hết hạn nên không phình to.
 *
 * <ul>
 *   <li>Theo từng token (đăng xuất): khoá {@code auth:deny:{jti}}.</li>
 *   <li>Theo người dùng (khoá tài khoản, đổi / đặt lại mật khẩu): khoá
 *       {@code auth:revoked-before:{userId}} lưu mốc thời gian; mọi token phát hành <b>trước</b> mốc
 *       đó đều bị từ chối. Token cấp ngay sau đó (cùng giây trở đi) vẫn dùng được.</li>
 * </ul>
 */
@Service
public class AccessTokenDenylist {

    private static final Logger log = LoggerFactory.getLogger(AccessTokenDenylist.class);
    private static final String PREFIX = "auth:deny:";
    private static final String USER_PREFIX = "auth:revoked-before:";
    /** Dư ra một chút so với hạn access token để mốc thu hồi không hết trước token cuối cùng. */
    private static final Duration TTL_MARGIN = Duration.ofMinutes(1);

    private final StringRedisTemplate redis;
    private final Duration accessTokenTtl;

    public AccessTokenDenylist(StringRedisTemplate redis,
                               @Value("${jwt.access-token-ttl:PT30M}") Duration accessTokenTtl) {
        this.redis = redis;
        this.accessTokenTtl = accessTokenTtl;
    }

    /** Thu hồi mọi access token đã cấp cho người dùng tính đến thời điểm này. */
    public void revokeUserTokens(Long userId) {
        redis.opsForValue().set(USER_PREFIX + userId,
                String.valueOf(Instant.now().getEpochSecond()),
                accessTokenTtl.plus(TTL_MARGIN));
    }

    /**
     * Token có bị thu hồi không, theo từng token hoặc theo người dùng. Redis lỗi thì coi như chưa
     * bị thu hồi (fail-open), xem {@link #isDenied(String)}.
     */
    public boolean isRevoked(AccessTokenClaims claims) {
        if (isDenied(claims.tokenId())) {
            return true;
        }
        try {
            String revokedBefore = redis.opsForValue().get(USER_PREFIX + claims.userId());
            return revokedBefore != null && claims.issuedAt().getEpochSecond() < Long.parseLong(revokedBefore);
        } catch (RuntimeException e) {
            log.warn("Không kiểm tra được mốc thu hồi token của user {}: {}", claims.userId(), e.getMessage());
            return false;
        }
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
