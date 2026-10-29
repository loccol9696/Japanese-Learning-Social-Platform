package com.jlsp.backend.common.config;

import com.jlsp.backend.common.security.jwt.JwtAuthenticationFilter;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.web.servlet.FilterRegistrationBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.http.MediaType;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.time.LocalDateTime;
import java.util.List;

@Configuration
@EnableWebSecurity
@EnableMethodSecurity
public class SecurityConfig {

    /** API xác thực không cần token (đăng xuất cũng mở để thu hồi được refresh token đã hết phiên). */
    private static final String[] PUBLIC_AUTH_ENDPOINTS = {
            "/api/v1/auth/register",
            "/api/v1/auth/login",
            "/api/v1/auth/google",
            "/api/v1/auth/verify-otp",
            "/api/v1/auth/resend-otp",
            "/api/v1/auth/refresh",
            "/api/v1/auth/logout",
            "/api/v1/auth/forgot-password",
            "/api/v1/auth/reset-password",
    };

    /** Nội dung công khai chỉ đọc. */
    private static final String[] PUBLIC_GET_ENDPOINTS = {
            "/api/v1/videos",
            "/api/v1/videos/feed/**",
            "/api/v1/videos/user/*",
            "/api/v1/videos/{id:[0-9]+}",
            "/api/v1/videos/{id:[0-9]+}/comments",
            "/api/v1/videos/{id:[0-9]+}/subtitles",
            "/api/v1/users/*/videos",
            "/api/v1/users/*/public-profile",
            "/api/v1/topics/**",
            "/topics/**",
            "/api/v1/subscription-plans",
            "/api/v1/subscription-plans/{id:[0-9]+}",
            "/api/v1/dictionary/**",
    };

    @Value("${app.security.enabled:true}")
    private boolean securityEnabled;

    /** Danh sách origin được phép gọi API từ trình duyệt, phân tách bằng dấu phẩy. */
    @Value("${CORS_ALLOWED_ORIGINS:}")
    private String corsAllowedOrigins;

    @Value("${spring.profiles.active:dev}")
    private String activeProfiles;

    private final JwtAuthenticationFilter jwtAuthenticationFilter;

    public SecurityConfig(JwtAuthenticationFilter jwtAuthenticationFilter) {
        this.jwtAuthenticationFilter = jwtAuthenticationFilter;
    }

    /**
     * Spring Boot mặc định đăng ký mọi bean {@code Filter} thành servlet filter độc lập. Với filter JWT
     * điều đó nguy hiểm: nếu bản độc lập chạy trước chuỗi bảo mật thì {@code SecurityContextHolderFilter}
     * xoá mất xác thực vừa gắn, còn bản trong chuỗi bị bỏ qua (OncePerRequestFilter). Tắt đăng ký độc lập để
     * filter này chỉ chạy đúng một lần, trong chuỗi bảo mật, không phụ thuộc thứ tự đăng ký.
     */
    @Bean
    public FilterRegistrationBean<JwtAuthenticationFilter> jwtAuthenticationFilterRegistration(
            JwtAuthenticationFilter filter) {
        FilterRegistrationBean<JwtAuthenticationFilter> registration = new FilterRegistrationBean<>(filter);
        registration.setEnabled(false);
        return registration;
    }

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
                .cors(cors -> cors.configurationSource(corsConfigurationSource()))
                .csrf(csrf -> csrf.disable())
                .httpBasic(basic -> basic.disable())
                .formLogin(form -> form.disable())
                .sessionManagement(sess -> sess.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .exceptionHandling(ex -> ex
                        .authenticationEntryPoint((req, resp, e) ->
                                writeJsonError(resp, HttpServletResponse.SC_UNAUTHORIZED,
                                        "Vui lòng đăng nhập để tiếp tục"))
                        .accessDeniedHandler((req, resp, e) ->
                                writeJsonError(resp, HttpServletResponse.SC_FORBIDDEN,
                                        "Bạn không có quyền thực hiện hành động này")))
                .addFilterBefore(jwtAuthenticationFilter, UsernamePasswordAuthenticationFilter.class);

        if (!securityEnabled) {
            // Chỉ dùng khi chủ động tắt (app.security.enabled=false) để debug cục bộ.
            http.authorizeHttpRequests(auth -> auth.anyRequest().permitAll());
            return http.build();
        }

        http.authorizeHttpRequests(auth -> auth
                .requestMatchers(HttpMethod.OPTIONS, "/**").permitAll()
                .requestMatchers("/error").permitAll()
                .requestMatchers(HttpMethod.POST, PUBLIC_AUTH_ENDPOINTS).permitAll()
                // Webhook ngân hàng (SePay): không có JWT; tự xác thực bằng header Authorization: Apikey trong controller.
                .requestMatchers(HttpMethod.POST, "/api/v1/payments/webhook/sepay").permitAll()

                // Xử lý báo cáo: Admin và Moderator (phải đứng trước rule /admin/** chỉ cho ADMIN)
                .requestMatchers("/api/v1/admin/reports/**").hasAnyRole("ADMIN", "MODERATOR")

                // Quản trị
                .requestMatchers("/api/v1/admin/**").hasRole("ADMIN")
                .requestMatchers("/api/v1/users/admin-create", "/api/v1/users/admin-batch-create",
                        "/api/v1/users/admin-list", "/api/v1/users/*/toggle-status").hasRole("ADMIN")
                .requestMatchers(HttpMethod.POST, "/api/v1/users").hasRole("ADMIN")
                .requestMatchers(HttpMethod.GET, "/api/v1/users").hasRole("ADMIN")
                .requestMatchers(HttpMethod.PUT, "/api/v1/users/{id:[0-9]+}").hasRole("ADMIN")
                .requestMatchers(HttpMethod.DELETE, "/api/v1/users/{id:[0-9]+}").hasRole("ADMIN")
                .requestMatchers("/api/v1/subscription-plans/admin-all", "/api/v1/subscription-plans/admin/**",
                        "/api/v1/subscription-plans/token-rate").hasRole("ADMIN")
                .requestMatchers(HttpMethod.POST, "/api/v1/subscription-plans").hasRole("ADMIN")
                .requestMatchers(HttpMethod.PUT, "/api/v1/subscription-plans/**").hasRole("ADMIN")
                .requestMatchers(HttpMethod.DELETE, "/api/v1/subscription-plans/**").hasRole("ADMIN")
                .requestMatchers("/api/v1/topics/admin/**", "/topics/admin/**").hasRole("ADMIN")

                // Kiểm duyệt video
                .requestMatchers("/api/v1/videos/moderation", "/api/v1/videos/*/approve",
                        "/api/v1/videos/*/reject").hasAnyRole("ADMIN", "MODERATOR")

                // Nội dung công khai
                .requestMatchers(HttpMethod.GET, PUBLIC_GET_ENDPOINTS).permitAll()
                .requestMatchers(HttpMethod.POST, "/api/v1/videos/*/views").permitAll()

                // Còn lại: bắt buộc đăng nhập
                .anyRequest().authenticated());

        return http.build();
    }

    private static void writeJsonError(HttpServletResponse resp, int status, String message) throws IOException {
        resp.setStatus(status);
        resp.setContentType(MediaType.APPLICATION_JSON_VALUE);
        resp.setCharacterEncoding(StandardCharsets.UTF_8.name());
        resp.getWriter().write(String.format(
                "{\"status\":%d,\"message\":\"%s\",\"data\":null,\"timestamp\":\"%s\"}",
                status, message, LocalDateTime.now()));
    }

    @Bean
    public CorsConfigurationSource corsConfigurationSource() {
        CorsConfiguration configuration = new CorsConfiguration();
        configuration.setAllowedOriginPatterns(
                resolveCorsOrigins(corsAllowedOrigins, activeProfiles.contains("prod")));
        configuration.setAllowedMethods(List.of("GET", "POST", "PUT", "DELETE", "OPTIONS", "PATCH"));
        configuration.setAllowedHeaders(List.of("*"));

        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", configuration);
        return source;
    }

    /**
     * Origin được phép: lấy từ {@code CORS_ALLOWED_ORIGINS}. Để trống thì dev cho mọi origin; prod
     * bắt buộc khai báo cụ thể và không được dùng ký tự đại diện {@code *}, nếu không server không khởi động.
     */
    static List<String> resolveCorsOrigins(String csv, boolean prod) {
        List<String> origins = csv == null ? List.of() : java.util.Arrays.stream(csv.split(","))
                .map(String::trim)
                .filter(o -> !o.isEmpty())
                .toList();
        if (origins.isEmpty()) {
            if (prod) {
                throw new IllegalStateException(
                        "CORS_ALLOWED_ORIGINS là bắt buộc ở profile prod (ví dụ: https://admin.example.com)");
            }
            return List.of("*");
        }
        if (prod && origins.contains("*")) {
            throw new IllegalStateException("CORS_ALLOWED_ORIGINS không được chứa \"*\" ở profile prod");
        }
        return origins;
    }

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }
}
