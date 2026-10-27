package com.jlsp.backend.common.security.token;

import com.jlsp.backend.common.exception.AppException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.mockito.ArgumentMatchers;
import org.springframework.data.redis.core.SetOperations;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;

import java.time.Duration;
import java.util.Collection;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class RefreshTokenServiceTest {

    private StringRedisTemplate redis;
    private ValueOperations<String, String> values;
    private SetOperations<String, String> sets;
    private AccessTokenDenylist denylist;
    private RefreshTokenService service;

    @BeforeEach
    @SuppressWarnings("unchecked")
    void setUp() {
        redis = mock(StringRedisTemplate.class);
        values = mock(ValueOperations.class);
        sets = mock(SetOperations.class);
        when(redis.opsForValue()).thenReturn(values);
        when(redis.opsForSet()).thenReturn(sets);
        denylist = mock(AccessTokenDenylist.class);
        service = new RefreshTokenService(redis, Duration.ofDays(14), denylist);
    }

    @Test
    void storesOnlyTheHashNeverTheRawToken() {
        String token = service.issue(7L);

        ArgumentCaptor<String> key = ArgumentCaptor.forClass(String.class);
        verify(values).set(key.capture(), eq("7"), eq(Duration.ofDays(14)));
        assertThat(key.getValue()).isEqualTo("auth:rt:" + RefreshTokenService.hash(token));
        assertThat(key.getValue()).doesNotContain(token);
    }

    @Test
    void tokensAreRandomAndUrlSafe() {
        String a = service.issue(7L);
        String b = service.issue(7L);
        assertThat(a).isNotEqualTo(b).matches("[A-Za-z0-9_-]{43}");
    }

    @Test
    void consumeIsOneTimeAndReturnsUserId() {
        when(values.getAndDelete("auth:rt:" + RefreshTokenService.hash("abc"))).thenReturn("7");

        assertThat(service.consume("abc")).isEqualTo(7L);
        verify(sets).remove("auth:rt:user:7", RefreshTokenService.hash("abc"));
    }

    @Test
    void unknownOrReusedTokenIsUnauthorized() {
        when(values.getAndDelete(anyString())).thenReturn(null);

        assertThatThrownBy(() -> service.consume("already-used"))
                .isInstanceOf(AppException.class)
                .extracting("status").isEqualTo(401);
        assertThatThrownBy(() -> service.consume(" "))
                .isInstanceOf(AppException.class);
    }

    @Test
    void revokeAllDeletesEveryDeviceToken() {
        when(sets.members("auth:rt:user:7")).thenReturn(java.util.Set.of("h1", "h2"));

        service.revokeAll(7L);
        // Access token đã cấp cũng bị vô hiệu hoá, không chỉ refresh token.
        verify(denylist).revokeUserTokens(7L);

        verify(redis).delete("auth:rt:h1");
        verify(redis).delete("auth:rt:h2");
        verify(redis).delete("auth:rt:user:7");
        verify(redis, org.mockito.Mockito.never()).delete(ArgumentMatchers.<Collection<String>>any());
    }
}
