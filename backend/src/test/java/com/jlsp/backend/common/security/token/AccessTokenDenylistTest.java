package com.jlsp.backend.common.security.token;

import com.jlsp.backend.common.security.jwt.JwtUtils.AccessTokenClaims;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;

import java.time.Duration;
import java.time.Instant;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class AccessTokenDenylistTest {

    private static final long USER = 7L;

    private StringRedisTemplate redis;
    private ValueOperations<String, String> values;
    private AccessTokenDenylist denylist;

    @BeforeEach
    @SuppressWarnings("unchecked")
    void setUp() {
        redis = mock(StringRedisTemplate.class);
        values = mock(ValueOperations.class);
        when(redis.opsForValue()).thenReturn(values);
        denylist = new AccessTokenDenylist(redis, Duration.ofMinutes(30));
    }

    private static AccessTokenClaims claims(Instant issuedAt) {
        return new AccessTokenClaims(USER, "bob", List.of("ROLE_USER"), "jti-1",
                issuedAt.plus(Duration.ofMinutes(30)), issuedAt);
    }

    @Test
    void revokingAUserStoresTheMomentWithATtlLongerThanTheAccessToken() {
        Instant before = Instant.now();

        denylist.revokeUserTokens(USER);

        ArgumentCaptor<String> moment = ArgumentCaptor.forClass(String.class);
        verify(values).set(eq("auth:revoked-before:7"), moment.capture(), eq(Duration.ofMinutes(31)));
        assertThat(Long.parseLong(moment.getValue()))
                .isBetween(before.getEpochSecond(), Instant.now().getEpochSecond());
    }

    @Test
    void tokenIssuedBeforeTheRevocationMomentIsRevoked() {
        Instant now = Instant.now();
        when(values.get("auth:revoked-before:7")).thenReturn(String.valueOf(now.getEpochSecond()));

        assertThat(denylist.isRevoked(claims(now.minusSeconds(60)))).isTrue();
    }

    @Test
    void tokenIssuedAtOrAfterTheRevocationMomentStillWorks() {
        Instant now = Instant.now();
        when(values.get("auth:revoked-before:7")).thenReturn(String.valueOf(now.getEpochSecond()));

        // Token cấp ngay sau khi đổi mật khẩu (cùng giây) không được bị chính lần thu hồi đó chặn.
        assertThat(denylist.isRevoked(claims(Instant.ofEpochSecond(now.getEpochSecond())))).isFalse();
        assertThat(denylist.isRevoked(claims(now.plusSeconds(5)))).isFalse();
    }

    @Test
    void usersWithoutARevocationMarkerAreNotAffected() {
        when(values.get("auth:revoked-before:7")).thenReturn(null);

        assertThat(denylist.isRevoked(claims(Instant.now().minusSeconds(600)))).isFalse();
    }

    @Test
    void anIndividuallyDeniedTokenIsRevokedEvenWithoutAUserMarker() {
        when(redis.hasKey("auth:deny:jti-1")).thenReturn(true);

        assertThat(denylist.isRevoked(claims(Instant.now()))).isTrue();
    }

    @Test
    void redisFailureFailsOpen() {
        when(redis.hasKey("auth:deny:jti-1")).thenThrow(new IllegalStateException("redis down"));
        when(values.get("auth:revoked-before:7")).thenThrow(new IllegalStateException("redis down"));

        assertThat(denylist.isRevoked(claims(Instant.now()))).isFalse();
    }
}
