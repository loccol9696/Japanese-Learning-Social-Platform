package com.jlsp.backend.otp.service;

import com.jlsp.backend.common.exception.AppException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;

import java.time.Duration;
import java.util.concurrent.TimeUnit;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class OtpRedisServiceTest {

    private static final String EMAIL = "sakura@example.com";

    private StringRedisTemplate redis;
    private ValueOperations<String, String> values;
    private OtpRedisService service;

    @BeforeEach
    @SuppressWarnings("unchecked")
    void setUp() {
        redis = mock(StringRedisTemplate.class);
        values = mock(ValueOperations.class);
        when(redis.opsForValue()).thenReturn(values);
        service = new OtpRedisService(redis);
    }

    @Test
    void resendWithinCooldownIsRejected() {
        when(redis.getExpire("otp:cooldown:verify:" + EMAIL, TimeUnit.SECONDS)).thenReturn(42L);

        assertThatThrownBy(() -> service.issue(OtpPurpose.VERIFY_EMAIL, EMAIL))
                .isInstanceOf(AppException.class)
                .hasMessageContaining("42 giây")
                .extracting("status").isEqualTo(429);
        verify(values, never()).set(eq("otp:verify:" + EMAIL), anyString(), any(Duration.class));
    }

    @Test
    void tooManySendsPerHourIsRejected() {
        when(values.increment("otp:hourly:" + EMAIL)).thenReturn(6L);

        assertThatThrownBy(() -> service.issue(OtpPurpose.VERIFY_EMAIL, EMAIL))
                .isInstanceOf(AppException.class)
                .extracting("status").isEqualTo(429);
    }

    @Test
    void issueStoresSixDigitCodeAndStartsCooldown() {
        when(values.increment("otp:hourly:" + EMAIL)).thenReturn(1L);

        String code = service.issue(OtpPurpose.RESET_PASSWORD, EMAIL);

        org.assertj.core.api.Assertions.assertThat(code).matches("\\d{6}");
        verify(values).set("otp:reset:" + EMAIL, code, Duration.ofMinutes(5));
        verify(values).set("otp:cooldown:reset:" + EMAIL, "1", Duration.ofSeconds(60));
    }

    @Test
    void wrongCodeReportsRemainingAttempts() {
        when(values.get("otp:verify:" + EMAIL)).thenReturn("123456");
        when(values.increment("otp:attempts:verify:" + EMAIL)).thenReturn(2L);

        assertThatThrownBy(() -> service.verify(OtpPurpose.VERIFY_EMAIL, EMAIL, "000000"))
                .isInstanceOf(AppException.class)
                .hasMessageContaining("còn 3 lần")
                .extracting("status").isEqualTo(400);
        verify(redis, never()).delete("otp:verify:" + EMAIL);
    }

    @Test
    void sixthAttemptBurnsTheCode() {
        when(values.get("otp:verify:" + EMAIL)).thenReturn("123456");
        when(values.increment("otp:attempts:verify:" + EMAIL)).thenReturn(6L);

        assertThatThrownBy(() -> service.verify(OtpPurpose.VERIFY_EMAIL, EMAIL, "123456"))
                .isInstanceOf(AppException.class)
                .extracting("status").isEqualTo(429);
        verify(redis).delete("otp:verify:" + EMAIL);
    }

    @Test
    void correctCodeIsSingleUse() {
        when(values.get("otp:verify:" + EMAIL)).thenReturn("123456");
        when(values.increment("otp:attempts:verify:" + EMAIL)).thenReturn(1L);

        assertThatCode(() -> service.verify(OtpPurpose.VERIFY_EMAIL, EMAIL, " 123456 ")).doesNotThrowAnyException();
        verify(redis).delete("otp:verify:" + EMAIL);
        verify(redis).delete("otp:attempts:verify:" + EMAIL);
    }

    @Test
    void codeForOnePurposeCannotBeUsedForAnother() {
        when(values.get("otp:verify:" + EMAIL)).thenReturn("123456");
        when(values.get("otp:reset:" + EMAIL)).thenReturn(null);

        assertThatThrownBy(() -> service.verify(OtpPurpose.RESET_PASSWORD, EMAIL, "123456"))
                .isInstanceOf(AppException.class)
                .extracting("status").isEqualTo(400);
    }
}
