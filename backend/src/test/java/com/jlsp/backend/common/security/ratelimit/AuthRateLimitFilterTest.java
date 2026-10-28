package com.jlsp.backend.common.security.ratelimit;

import com.jlsp.backend.common.security.ratelimit.RateLimiter.Decision;
import jakarta.servlet.FilterChain;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class AuthRateLimitFilterTest {

    private RateLimiter limiter;
    private FilterChain chain;

    @BeforeEach
    void setUp() {
        limiter = mock(RateLimiter.class);
        chain = mock(FilterChain.class);
        when(limiter.tryAcquire(anyString(), anyInt(), any())).thenReturn(Decision.ALLOWED);
    }

    private AuthRateLimitFilter filter(boolean enabled, boolean trustForwardedFor) {
        return new AuthRateLimitFilter(limiter, enabled, new ClientIpResolver(trustForwardedFor));
    }

    private static MockHttpServletRequest post(String path) {
        MockHttpServletRequest request = new MockHttpServletRequest("POST", path);
        request.setRemoteAddr("10.0.0.5");
        return request;
    }

    @Test
    void allowedRequestsContinueDownTheChain() throws Exception {
        MockHttpServletResponse response = new MockHttpServletResponse();
        MockHttpServletRequest request = post("/api/v1/auth/login");

        filter(true, false).doFilter(request, response, chain);

        verify(chain).doFilter(request, response);
        assertThat(response.getStatus()).isEqualTo(200);
    }

    @Test
    void rejectedRequestGets429WithRetryAfterAndTheStandardJsonBody() throws Exception {
        when(limiter.tryAcquire(anyString(), anyInt(), any())).thenReturn(new Decision(false, 42));
        MockHttpServletResponse response = new MockHttpServletResponse();

        filter(true, false).doFilter(post("/api/v1/auth/login"), response, chain);

        assertThat(response.getStatus()).isEqualTo(429);
        assertThat(response.getHeader("Retry-After")).isEqualTo("42");
        assertThat(response.getContentType()).startsWith("application/json");
        assertThat(response.getContentAsString(java.nio.charset.StandardCharsets.UTF_8))
                .contains("\"status\":429").contains("42 giây").contains("\"data\":null");
        verify(chain, never()).doFilter(any(), any());
    }

    @Test
    void limitIsKeyedByRuleAndIp() throws Exception {
        filter(true, false).doFilter(post("/api/v1/auth/register"), new MockHttpServletResponse(), chain);

        ArgumentCaptor<String> key = ArgumentCaptor.forClass(String.class);
        verify(limiter).tryAcquire(key.capture(), eq(10), eq(java.time.Duration.ofHours(1)));
        assertThat(key.getValue()).isEqualTo("register:10.0.0.5");
    }

    @Test
    void trailingSlashDoesNotEscapeTheLimit() throws Exception {
        filter(true, false).doFilter(post("/api/v1/auth/login/"), new MockHttpServletResponse(), chain);

        verify(limiter).tryAcquire(eq("login:10.0.0.5"), anyInt(), any());
    }

    @Test
    void forwardedHeaderIsIgnoredUnlessProxyIsTrusted() throws Exception {
        MockHttpServletRequest request = post("/api/v1/auth/login");
        request.addHeader("X-Forwarded-For", "203.0.113.9, 10.0.0.1");

        filter(true, false).doFilter(request, new MockHttpServletResponse(), chain);
        verify(limiter).tryAcquire(eq("login:10.0.0.5"), anyInt(), any());

        filter(true, true).doFilter(request, new MockHttpServletResponse(), chain);
        verify(limiter).tryAcquire(eq("login:203.0.113.9"), anyInt(), any());
    }

    @Test
    void otherEndpointsAndMethodsAreNotLimited() throws Exception {
        filter(true, false).doFilter(post("/api/v1/videos"), new MockHttpServletResponse(), chain);
        filter(true, false).doFilter(
                new MockHttpServletRequest("GET", "/api/v1/auth/login"), new MockHttpServletResponse(), chain);

        verify(limiter, never()).tryAcquire(anyString(), anyInt(), any());
    }

    @Test
    void canBeSwitchedOff() throws Exception {
        filter(false, false).doFilter(post("/api/v1/auth/login"), new MockHttpServletResponse(), chain);

        verify(limiter, never()).tryAcquire(anyString(), anyInt(), any());
    }
}
