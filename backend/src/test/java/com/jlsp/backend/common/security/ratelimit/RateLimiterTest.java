package com.jlsp.backend.common.security.ratelimit;

import com.jlsp.backend.common.security.ratelimit.RateLimiter.Decision;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;

import java.time.Duration;
import java.util.concurrent.TimeUnit;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class RateLimiterTest {

    private static final Duration WINDOW = Duration.ofMinutes(5);

    private StringRedisTemplate redis;
    private ValueOperations<String, String> values;
    private RateLimiter limiter;

    @BeforeEach
    @SuppressWarnings("unchecked")
    void setUp() {
        redis = mock(StringRedisTemplate.class);
        values = mock(ValueOperations.class);
        when(redis.opsForValue()).thenReturn(values);
        limiter = new RateLimiter(redis);
    }

    @Test
    void firstRequestStartsTheWindow() {
        when(values.increment("ratelimit:login:1.2.3.4")).thenReturn(1L);

        assertThat(limiter.tryAcquire("login:1.2.3.4", 3, WINDOW)).isEqualTo(Decision.ALLOWED);

        verify(redis).expire("ratelimit:login:1.2.3.4", WINDOW);
    }

    @Test
    void requestsUpToTheLimitAreAllowedWithoutResettingTheWindow() {
        when(values.increment("ratelimit:k")).thenReturn(3L);

        assertThat(limiter.tryAcquire("k", 3, WINDOW).allowed()).isTrue();

        verify(redis, never()).expire(any(), any(Duration.class));
    }

    @Test
    void requestOverTheLimitIsRejectedWithTheRemainingTime() {
        when(values.increment("ratelimit:k")).thenReturn(4L);
        when(redis.getExpire("ratelimit:k", TimeUnit.SECONDS)).thenReturn(120L);

        Decision decision = limiter.tryAcquire("k", 3, WINDOW);

        assertThat(decision.allowed()).isFalse();
        assertThat(decision.retryAfterSeconds()).isEqualTo(120L);
    }

    @Test
    void aKeyThatLostItsTtlIsGivenOneSoItCannotBlockForever() {
        when(values.increment("ratelimit:k")).thenReturn(9L);
        when(redis.getExpire("ratelimit:k", TimeUnit.SECONDS)).thenReturn(-1L);

        Decision decision = limiter.tryAcquire("k", 3, WINDOW);

        assertThat(decision.allowed()).isFalse();
        assertThat(decision.retryAfterSeconds()).isEqualTo(WINDOW.toSeconds());
        verify(redis).expire("ratelimit:k", WINDOW);
    }

    @Test
    void redisFailureLetsTheRequestThrough() {
        when(values.increment("ratelimit:k")).thenThrow(new IllegalStateException("redis down"));

        assertThat(limiter.tryAcquire("k", 3, WINDOW)).isEqualTo(Decision.ALLOWED);
    }
}
