package com.jlsp.backend.common.security.ratelimit;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.LocalDateTime;
import java.util.Map;

/**
 * Giới hạn số lần gọi các endpoint xác thực theo địa chỉ IP, chạy trước cả Spring Security. Bổ sung cho
 * việc khoá theo tài khoản ở {@code LoginAttemptService} (chỉ chặn dò mật khẩu một tài khoản) và giới hạn
 * OTP theo email: lớp này chặn một nguồn thử nhiều tài khoản, đăng ký hàng loạt, spam gửi mail.
 *
 * <ul>
 *   <li>Tắt bằng {@code RATE_LIMIT_ENABLED=false}.</li>
 *   <li>Mặc định lấy IP từ kết nối trực tiếp. Chỉ khi chạy sau reverse proxy đáng tin mới đặt
 *       {@code TRUST_FORWARDED_FOR=true} để dùng {@code X-Forwarded-For}; nếu không, mọi người dùng chung
 *       một IP của proxy và sẽ chặn lẫn nhau, còn nếu bật mà không có proxy thì kẻ tấn công tự giả IP.</li>
 * </ul>
 */
@Component
@Order(Ordered.HIGHEST_PRECEDENCE + 10)
public class AuthRateLimitFilter extends OncePerRequestFilter {

    record Rule(String name, int maxRequests, Duration window) {
    }

    static final Map<String, Rule> RULES = Map.of(
            "/api/v1/auth/login", new Rule("login", 30, Duration.ofMinutes(5)),
            "/api/v1/auth/google", new Rule("google", 30, Duration.ofMinutes(5)),
            "/api/v1/auth/register", new Rule("register", 10, Duration.ofHours(1)),
            "/api/v1/auth/resend-otp", new Rule("resend-otp", 10, Duration.ofHours(1)),
            "/api/v1/auth/forgot-password", new Rule("forgot-password", 10, Duration.ofHours(1)),
            "/api/v1/auth/verify-otp", new Rule("verify-otp", 20, Duration.ofMinutes(15)),
            "/api/v1/auth/reset-password", new Rule("reset-password", 20, Duration.ofMinutes(15)),
            "/api/v1/auth/refresh", new Rule("refresh", 60, Duration.ofMinutes(1)));

    private final RateLimiter rateLimiter;
    private final boolean enabled;
    private final boolean trustForwardedFor;

    public AuthRateLimitFilter(RateLimiter rateLimiter,
                               @Value("${RATE_LIMIT_ENABLED:true}") boolean enabled,
                               @Value("${TRUST_FORWARDED_FOR:false}") boolean trustForwardedFor) {
        this.rateLimiter = rateLimiter;
        this.enabled = enabled;
        this.trustForwardedFor = trustForwardedFor;
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        return !enabled
                || !"POST".equalsIgnoreCase(request.getMethod())
                || !RULES.containsKey(normalizedPath(request));
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {
        Rule rule = RULES.get(normalizedPath(request));
        RateLimiter.Decision decision = rateLimiter.tryAcquire(
                rule.name() + ":" + clientIp(request), rule.maxRequests(), rule.window());

        if (decision.allowed()) {
            chain.doFilter(request, response);
            return;
        }
        response.setStatus(429);
        response.setHeader("Retry-After", String.valueOf(decision.retryAfterSeconds()));
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        response.setCharacterEncoding(StandardCharsets.UTF_8.name());
        response.getWriter().write(String.format(
                "{\"status\":429,\"message\":\"Bạn thao tác quá nhanh. Vui lòng thử lại sau %d giây\","
                        + "\"data\":null,\"timestamp\":\"%s\"}",
                decision.retryAfterSeconds(), LocalDateTime.now()));
    }

    private static String normalizedPath(HttpServletRequest request) {
        String path = request.getRequestURI();
        return path.length() > 1 && path.endsWith("/") ? path.substring(0, path.length() - 1) : path;
    }

    String clientIp(HttpServletRequest request) {
        if (trustForwardedFor) {
            String forwarded = request.getHeader("X-Forwarded-For");
            if (forwarded != null && !forwarded.isBlank()) {
                // Phần tử đầu là client gốc; các phần tử sau là các proxy trung gian.
                return forwarded.split(",")[0].trim();
            }
        }
        return request.getRemoteAddr();
    }
}
