package com.jlsp.backend.common.security;

import com.jlsp.backend.common.config.SecurityConfig;
import com.jlsp.backend.common.security.jwt.JwtUtils;
import com.jlsp.backend.common.security.ratelimit.ClientIpResolver;
import com.jlsp.backend.common.security.ratelimit.RateLimiter;
import com.jlsp.backend.common.security.token.AccessTokenDenylist;
import com.jlsp.backend.user.entity.User;
import com.jlsp.backend.user.entity.UserRole;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.HttpMethod;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.Duration;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.request;

/**
 * Ma trận phân quyền của {@link SecurityConfig}: ai (khách, USER, MODERATOR, ADMIN) được gọi đường dẫn nào.
 *
 * <p>Chỉ kiểm tra tầng bảo mật nên dùng một controller giả bắt mọi đường dẫn và trả 200; nếu không bị chặn
 * ở filter thì request tới được controller. JWT là thật (ký bằng khoá thử nghiệm), Redis được mock.
 * Thêm endpoint mới cần phân quyền đặc biệt thì thêm một dòng vào bảng bên dưới.
 */
@WebMvcTest(controllers = SecurityMatrixTest.EchoController.class)
@Import({SecurityConfig.class, JwtUtils.class, ClientIpResolver.class, SecurityMatrixTest.EchoController.class})
@TestPropertySource(properties = {
        "jwt.secret=test-secret-key-that-is-long-enough-for-hs256!!",
        "jwt.issuer=jlsp-backend"
})
class SecurityMatrixTest {

    private static final String SECRET = "test-secret-key-that-is-long-enough-for-hs256!!";

    /** Trả 200 cho mọi phương thức và đường dẫn: chỉ để biết request có vượt được bộ lọc bảo mật không. */
    @RestController
    static class EchoController {
        @RequestMapping("/**")
        String any() {
            return "ok";
        }
    }

    @Autowired
    private MockMvc mockMvc;
    @Autowired
    private JwtUtils jwtUtils;

    @MockitoBean
    private AccessTokenDenylist denylist;
    @MockitoBean
    private RateLimiter rateLimiter;

    @BeforeEach
    void allowRateLimiter() {
        when(rateLimiter.tryAcquire(anyString(), anyInt(), any())).thenReturn(RateLimiter.Decision.ALLOWED);
    }

    // ------------------------------------------------------------------ tiện ích

    private String tokenFor(UserRole role) {
        return jwtUtils.generateAccessToken(
                User.builder().id(1L).username("tester").role(role).build());
    }

    /** "GET /api/v1/videos" -> trạng thái HTTP khi gọi bằng {@code token} (null = khách). */
    private int call(String methodAndPath, String token) throws Exception {
        String[] parts = methodAndPath.split(" ", 2);
        MockHttpServletRequestBuilder req = request(HttpMethod.valueOf(parts[0]), parts[1]);
        if (token != null) {
            req.header("Authorization", "Bearer " + token);
        }
        return mockMvc.perform(req).andReturn().getResponse().getStatus();
    }

    // ------------------------------------------------------------------ công khai

    @ParameterizedTest(name = "khách gọi {0} được")
    @ValueSource(strings = {
            "GET /api/v1/videos",
            "GET /api/v1/videos/feed/for-you",
            "GET /api/v1/videos/feed/following",
            "GET /api/v1/videos/42",
            "GET /api/v1/videos/42/comments",
            "GET /api/v1/videos/42/subtitles",
            "GET /api/v1/videos/user/7",
            "GET /api/v1/users/7/videos",
            "GET /api/v1/users/7/public-profile",
            "GET /api/v1/topics",
            "GET /topics",
            "GET /api/v1/subscription-plans",
            "GET /api/v1/subscription-plans/3",
            "GET /api/v1/dictionary/lookup",
            "POST /api/v1/videos/42/views",
            "POST /api/v1/auth/login",
            "POST /api/v1/auth/register",
            "POST /api/v1/auth/google",
            "POST /api/v1/auth/refresh",
            "POST /api/v1/auth/logout",
            "POST /api/v1/auth/verify-otp",
            "POST /api/v1/auth/resend-otp",
            "POST /api/v1/auth/forgot-password",
            "POST /api/v1/auth/reset-password",
            // Webhook ngân hàng: không có JWT; controller tự xác thực khoá Apikey (có test riêng).
            "POST /api/v1/payments/webhook/sepay",
    })
    void publicEndpointsDoNotNeedLogin(String endpoint) throws Exception {
        assertThat(call(endpoint, null)).isEqualTo(200);
    }

    // ------------------------------------------------------------------ cần đăng nhập

    private static final String[] LOGIN_REQUIRED = {
            "GET /api/v1/profile",
            "PUT /api/v1/profile",
            "GET /api/v1/onboarding",
            "PUT /api/v1/onboarding",
            "POST /api/v1/onboarding/skip",
            "GET /api/v1/notifications",
            "GET /api/v1/notifications/unread-count",
            "POST /api/v1/notifications/read-all",
            "GET /api/v1/chat/contacts",
            "GET /api/v1/chat/conversations",
            "POST /api/v1/reports",
            "GET /api/v1/flashcards/sets",
            "POST /api/v1/flashcards/study/review",
            "POST /api/v1/videos",
            "POST /api/v1/videos/42/likes",
            "POST /api/v1/videos/42/saves",
            "POST /api/v1/videos/42/comments",
            "POST /api/v1/videos/42/shadowing/lines/0/score",
            "GET /api/v1/videos/my-status",
            "POST /api/v1/users/7/follow",
            "POST /api/v1/users/7/block",
            "GET /api/v1/users/me/blocked",
            "GET /api/v1/users/search",
            "POST /api/v1/auth/change-password",
            "POST /api/v1/media/upload",
            "POST /api/v1/payments/orders",
            "GET /api/v1/payments/orders",
            "GET /api/v1/payments/orders/JLSPABCD2345",
            "GET /api/v1/payments/my-subscription",
            "GET /api/v1/payments/my-quota",
            "POST /api/speech/transcribe",
    };

    @Test
    void protectedEndpointsRejectGuestsWith401() throws Exception {
        for (String endpoint : LOGIN_REQUIRED) {
            assertThat(call(endpoint, null)).as("khách gọi %s", endpoint).isEqualTo(401);
        }
    }

    @Test
    void protectedEndpointsAcceptAnyRoleOnceLoggedIn() throws Exception {
        for (UserRole role : UserRole.values()) {
            String token = tokenFor(role);
            for (String endpoint : LOGIN_REQUIRED) {
                assertThat(call(endpoint, token)).as("%s gọi %s", role, endpoint).isEqualTo(200);
            }
        }
    }

    @Test
    void unknownPathsAreDeniedByDefaultForGuests() throws Exception {
        assertThat(call("GET /api/v1/something-new", null)).isEqualTo(401);
        assertThat(call("DELETE /api/v1/videos/42", null)).isEqualTo(401);
        assertThat(call("PUT /api/v1/videos/42", null)).isEqualTo(401);
    }

    // ------------------------------------------------------------------ đường dẫn thanh toán cũ không được mở lại

    /**
     * Các đường dẫn từng bị mở công khai (hoặc tự xác nhận thanh toán) ở bản thanh toán cũ. Chúng không còn tồn tại và
     * khách gọi vào phải bị chặn ở bộ lọc bảo mật, kể cả khi sau này ai đó thêm lại alias.
     */
    private static final String[] LEGACY_PAYMENT_PATHS = {
            "POST /api/v1/payments/confirm",
            "POST /api/v1/payments/approve/TX-123456",
            "POST /api/v1/payments/admin/approve/TX-123456",
            "POST /api/v1/payments/create-qr-order",
            "POST /api/v1/payments/checkout",
            "POST /api/v1/payments/sepay-token",
            "GET /api/v1/payments/sepay-token/status",
            "POST /api/v1/payments/webhook/casso",
            "GET /api/v1/payments/my-status",
            "GET /api/v1/payments/history",
            "GET /api/v1/payments/order-status/TX-123456",
            "GET /api/v1/subscriptions/history",
            "POST /api/v1/subscriptions/confirm",
            "PUT /api/v1/subscriptions/plans/3",
            "POST /api/v1/subscriptions/plans/admin",
            "DELETE /api/v1/subscriptions/plans/admin/3",
            "GET /api/payment/history",
            "POST /api/payment/confirm",
            "POST /api/payment/webhook/sepay",
    };

    @Test
    void legacyPaymentPathsAreNotOpenToGuests() throws Exception {
        for (String endpoint : LEGACY_PAYMENT_PATHS) {
            assertThat(call(endpoint, null)).as("khách gọi %s", endpoint).isEqualTo(401);
        }
    }

    // ------------------------------------------------------------------ chỉ ADMIN

    private static final String[] ADMIN_ONLY = {
            "GET /api/v1/admin/analytics",
            "GET /api/v1/admin/analytics/trend",
            "POST /api/v1/admin/subtitles/resplit",
            "GET /api/v1/users/admin-list",
            "POST /api/v1/users/admin-create",
            "POST /api/v1/users/admin-batch-create",
            "PATCH /api/v1/users/5/toggle-status",
            "GET /api/v1/users",
            "POST /api/v1/users",
            "PUT /api/v1/users/5",
            "DELETE /api/v1/users/5",
            "GET /api/v1/topics/admin",
            "POST /api/v1/topics/admin",
            "PUT /api/v1/topics/admin/3",
            "DELETE /api/v1/topics/admin/3",
            "GET /api/v1/admin/payments",
            "POST /api/v1/admin/payments/JLSPABCD2345/confirm",
            "GET /api/v1/subscription-plans/admin-all",
            "POST /api/v1/subscription-plans",
            "PUT /api/v1/subscription-plans/3",
            "DELETE /api/v1/subscription-plans/3",
            "PUT /api/v1/subscription-plans/token-rate",
    };

    @Test
    void adminEndpointsRejectGuestsAndOrdinaryUsers() throws Exception {
        for (String endpoint : ADMIN_ONLY) {
            assertThat(call(endpoint, null)).as("khách gọi %s", endpoint).isEqualTo(401);
            assertThat(call(endpoint, tokenFor(UserRole.USER))).as("USER gọi %s", endpoint).isEqualTo(403);
            assertThat(call(endpoint, tokenFor(UserRole.MODERATOR))).as("MODERATOR gọi %s", endpoint).isEqualTo(403);
        }
    }

    @Test
    void adminEndpointsAcceptAdmin() throws Exception {
        String admin = tokenFor(UserRole.ADMIN);
        for (String endpoint : ADMIN_ONLY) {
            assertThat(call(endpoint, admin)).as("ADMIN gọi %s", endpoint).isEqualTo(200);
        }
    }

    // ------------------------------------------------------------------ ADMIN và MODERATOR

    private static final String[] STAFF = {
            "GET /api/v1/videos/moderation",
            "POST /api/v1/videos/42/approve",
            "POST /api/v1/videos/42/reject",
            "GET /api/v1/admin/reports",
            "POST /api/v1/admin/reports/3/resolve",
            "POST /api/v1/admin/reports/3/dismiss",
    };

    @Test
    void moderationEndpointsAreForStaffOnly() throws Exception {
        for (String endpoint : STAFF) {
            assertThat(call(endpoint, null)).as("khách gọi %s", endpoint).isEqualTo(401);
            assertThat(call(endpoint, tokenFor(UserRole.USER))).as("USER gọi %s", endpoint).isEqualTo(403);
            assertThat(call(endpoint, tokenFor(UserRole.MODERATOR))).as("MODERATOR gọi %s", endpoint).isEqualTo(200);
            assertThat(call(endpoint, tokenFor(UserRole.ADMIN))).as("ADMIN gọi %s", endpoint).isEqualTo(200);
        }
    }

    // ------------------------------------------------------------------ xử lý token

    @Test
    void garbageTokenIsTreatedLikeAGuest() throws Exception {
        assertThat(call("GET /api/v1/profile", "not-a-jwt")).isEqualTo(401);
        // Endpoint công khai vẫn chạy bình thường dù token hỏng.
        assertThat(call("GET /api/v1/videos", "not-a-jwt")).isEqualTo(200);
    }

    @Test
    void expiredTokenIsRejected() throws Exception {
        String expired = new JwtUtils(SECRET, "jlsp-backend", Duration.ofSeconds(-5))
                .generateAccessToken(User.builder().id(1L).username("tester").role(UserRole.ADMIN).build());

        assertThat(call("GET /api/v1/admin/analytics", expired)).isEqualTo(401);
    }

    @Test
    void tokenSignedWithAnotherKeyOrIssuerIsRejected() throws Exception {
        User admin = User.builder().id(1L).username("tester").role(UserRole.ADMIN).build();
        String otherKey = new JwtUtils("another-secret-key-that-is-also-long-enough!!", "jlsp-backend",
                Duration.ofMinutes(30)).generateAccessToken(admin);
        String otherIssuer = new JwtUtils(SECRET, "someone-else", Duration.ofMinutes(30)).generateAccessToken(admin);

        assertThat(call("GET /api/v1/admin/analytics", otherKey)).isEqualTo(401);
        assertThat(call("GET /api/v1/admin/analytics", otherIssuer)).isEqualTo(401);
    }

    @Test
    void revokedTokenIsRejectedEvenIfItIsOtherwiseValid() throws Exception {
        when(denylist.isRevoked(any())).thenReturn(true);

        assertThat(call("GET /api/v1/profile", tokenFor(UserRole.USER))).isEqualTo(401);
        assertThat(call("GET /api/v1/admin/analytics", tokenFor(UserRole.ADMIN))).isEqualTo(401);
    }

    @Test
    void onlyTheBearerSchemeIsAccepted() throws Exception {
        MockHttpServletRequestBuilder req = request(HttpMethod.GET, "/api/v1/profile")
                .header("Authorization", "Basic " + tokenFor(UserRole.ADMIN));

        assertThat(mockMvc.perform(req).andReturn().getResponse().getStatus()).isEqualTo(401);
    }

    @Test
    void errorResponsesUseTheStandardJsonEnvelope() throws Exception {
        var unauthorized = mockMvc.perform(request(HttpMethod.GET, "/api/v1/profile")).andReturn().getResponse();
        var forbidden = mockMvc.perform(request(HttpMethod.GET, "/api/v1/admin/analytics")
                .header("Authorization", "Bearer " + tokenFor(UserRole.USER))).andReturn().getResponse();

        assertThat(unauthorized.getContentType()).startsWith("application/json");
        assertThat(unauthorized.getContentAsString(java.nio.charset.StandardCharsets.UTF_8))
                .contains("\"status\":401").contains("\"data\":null");
        assertThat(forbidden.getContentAsString(java.nio.charset.StandardCharsets.UTF_8))
                .contains("\"status\":403");
    }
}
