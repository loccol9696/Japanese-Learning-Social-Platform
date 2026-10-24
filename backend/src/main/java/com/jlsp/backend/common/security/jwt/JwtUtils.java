package com.jlsp.backend.common.security.jwt;

import com.jlsp.backend.user.entity.User;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import java.util.Date;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * Tạo và kiểm tra access token (JWT HS256, sống ngắn).
 * Claim: sub = username, uid = id người dùng, roles, jti (để thu hồi khi đăng xuất), iss.
 */
@Component
public class JwtUtils {

    private static final int MIN_SECRET_BYTES = 32;

    private final SecretKey signKey;
    private final String issuer;
    private final Duration accessTokenTtl;

    public JwtUtils(@Value("${jwt.secret}") String secret,
                    @Value("${jwt.issuer:jlsp-backend}") String issuer,
                    @Value("${jwt.access-token-ttl:PT30M}") Duration accessTokenTtl) {
        byte[] secretBytes = secret == null ? new byte[0] : secret.getBytes(StandardCharsets.UTF_8);
        if (secretBytes.length < MIN_SECRET_BYTES) {
            throw new IllegalStateException(
                    "jwt.secret (JWT_SECRET) phải dài tối thiểu " + MIN_SECRET_BYTES + " byte (256 bit)");
        }
        this.signKey = Keys.hmacShaKeyFor(secretBytes);
        this.issuer = issuer;
        this.accessTokenTtl = accessTokenTtl;
    }

    public Duration getAccessTokenTtl() {
        return accessTokenTtl;
    }

    public String generateAccessToken(User user) {
        Instant now = Instant.now();
        return Jwts.builder()
                .id(UUID.randomUUID().toString())
                .issuer(issuer)
                .subject(user.getUsername())
                .claim("uid", user.getId())
                .claim("roles", List.of("ROLE_" + user.getRole().name()))
                .issuedAt(Date.from(now))
                .expiration(Date.from(now.plus(accessTokenTtl)))
                .signWith(signKey)
                .compact();
    }

    /**
     * Giải mã và kiểm tra chữ ký, hạn dùng, issuer. Token sai/hết hạn/thiếu uid
     * (vd. token cũ trước khi refactor) đều trả về empty.
     */
    public Optional<AccessTokenClaims> parse(String token) {
        if (token == null || token.isBlank()) {
            return Optional.empty();
        }
        try {
            Claims claims = Jwts.parser()
                    .verifyWith(signKey)
                    .requireIssuer(issuer)
                    .build()
                    .parseSignedClaims(token)
                    .getPayload();

            Number uid = claims.get("uid", Number.class);
            if (uid == null || claims.getSubject() == null || claims.getId() == null) {
                return Optional.empty();
            }
            List<?> rawRoles = claims.get("roles", List.class);
            List<String> roles = rawRoles == null
                    ? List.of()
                    : rawRoles.stream().map(String::valueOf).toList();

            return Optional.of(new AccessTokenClaims(
                    uid.longValue(),
                    claims.getSubject(),
                    roles,
                    claims.getId(),
                    claims.getExpiration().toInstant()));
        } catch (JwtException | IllegalArgumentException e) {
            return Optional.empty();
        }
    }

    public record AccessTokenClaims(Long userId, String username, List<String> roles,
                                    String tokenId, Instant expiresAt) {
    }
}
