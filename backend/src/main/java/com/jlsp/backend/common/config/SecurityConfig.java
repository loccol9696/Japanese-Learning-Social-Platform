package com.jlsp.backend.common.config;

import com.jlsp.backend.common.security.CustomUserDetailsService;
import com.jlsp.backend.common.security.jwt.JwtAuthenticationFilter;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.web.servlet.FilterRegistrationBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.AuthenticationProvider;
import org.springframework.security.authentication.dao.DaoAuthenticationProvider;
import org.springframework.security.config.annotation.authentication.configuration.AuthenticationConfiguration;
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

import jakarta.servlet.http.HttpServletResponse;

import java.io.IOException;
import java.util.List;

@Configuration
@EnableWebSecurity
@EnableMethodSecurity
public class SecurityConfig {

    @Value("${app.security.enabled:true}")
    private boolean securityEnabled;

    private final JwtAuthenticationFilter jwtAuthenticationFilter;
    private final CustomUserDetailsService customUserDetailsService;

    public SecurityConfig(JwtAuthenticationFilter jwtAuthenticationFilter,
            CustomUserDetailsService customUserDetailsService) {
        this.jwtAuthenticationFilter = jwtAuthenticationFilter;
        this.customUserDetailsService = customUserDetailsService;
    }

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
                .cors(cors -> cors.configurationSource(corsConfigurationSource()))
                .csrf(csrf -> csrf.disable())
                .sessionManagement(sess -> sess.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .exceptionHandling(ex -> ex
                        .authenticationEntryPoint((req, resp, e) -> writeError(resp, HttpStatus.UNAUTHORIZED,
                                "Vui lòng đăng nhập để thực hiện thao tác này"))
                        .accessDeniedHandler((req, resp, e) -> writeError(resp, HttpStatus.FORBIDDEN,
                                "Bạn không có quyền truy cập chức năng này")))
                .authenticationProvider(authenticationProvider())
                // Luôn đọc JWT (kể cả DEV) để CurrentUser xác định được người dùng từ token
                .addFilterBefore(jwtAuthenticationFilter, UsernamePasswordAuthenticationFilter.class);

        if (!securityEnabled) {
            // Môi trường DEV: không chặn theo URL, nhưng endpoint cần danh tính vẫn trả 401 nếu thiếu token
            http.authorizeHttpRequests(auth -> auth.anyRequest().permitAll());
        } else {
            // Môi trường PROD: Áp dụng phân quyền chuẩn
            http.authorizeHttpRequests(auth -> auth
                    .requestMatchers("/error").permitAll()
                    .requestMatchers("/api/auth/**", "/api/v1/auth/**").permitAll()

                    // Quản trị
                    .requestMatchers("/api/v1/admin/**", "/api/admin/**").hasRole("ADMIN")
                    .requestMatchers("/api/v1/users/admin-*", "/api/v1/users/*/toggle-status").hasRole("ADMIN")
                    .requestMatchers(HttpMethod.GET, "/api/v1/users").hasRole("ADMIN")
                    .requestMatchers(HttpMethod.POST, "/api/v1/users").hasRole("ADMIN")
                    .requestMatchers(HttpMethod.DELETE, "/api/v1/users/*").hasRole("ADMIN")
                    .requestMatchers("/api/v1/payments/history").hasRole("ADMIN")
                    .requestMatchers("/api/v1/subscription-plans/admin-all", "/api/v1/subscription-plans/admin/**")
                            .hasRole("ADMIN")
                    .requestMatchers(HttpMethod.POST, "/api/v1/subscription-plans").hasRole("ADMIN")
                    .requestMatchers(HttpMethod.PUT, "/api/v1/subscription-plans/**").hasRole("ADMIN")

                    // Kiểm duyệt video
                    .requestMatchers("/api/v1/videos/moderation", "/api/v1/videos/*/approve",
                            "/api/v1/videos/*/reject", "/api/moderator/**").hasAnyRole("ADMIN", "MODERATOR")

                    // Nội dung công khai (khách xem được)
                    .requestMatchers(HttpMethod.GET, "/api/v1/videos", "/api/v1/videos/*",
                            "/api/v1/videos/*/subtitles", "/api/v1/videos/feed/for-you",
                            "/api/v1/videos/user/*").permitAll()
                    .requestMatchers(HttpMethod.POST, "/api/v1/videos/*/views").permitAll()
                    .requestMatchers(HttpMethod.GET, "/api/v1/users/*", "/api/v1/users/*/videos").permitAll()
                    .requestMatchers(HttpMethod.GET, "/api/v1/subscription-plans", "/api/v1/subscription-plans/*",
                            "/api/v1/subscription-plans/token-rate").permitAll()
                    .requestMatchers(HttpMethod.GET, "/api/v1/lessons", "/api/v1/lessons/*").permitAll()

                    .anyRequest().authenticated());
        }

        return http.build();
    }

    /** Trả lỗi 401/403 cùng format JSON với ApiResponse để client parse được message. */
    private static void writeError(HttpServletResponse resp, HttpStatus status, String message) throws IOException {
        resp.setStatus(status.value());
        resp.setContentType("application/json;charset=UTF-8");
        resp.getWriter().write("{\"status\":" + status.value() + ",\"message\":\"" + message + "\"}");
    }

    /** Chỉ chạy filter JWT trong security chain, không để Spring Boot tự đăng ký thêm làm servlet filter. */
    @Bean
    public FilterRegistrationBean<JwtAuthenticationFilter> jwtFilterRegistration(JwtAuthenticationFilter filter) {
        FilterRegistrationBean<JwtAuthenticationFilter> registration = new FilterRegistrationBean<>(filter);
        registration.setEnabled(false);
        return registration;
    }

    // Bean CORS luôn có sẵn cho cả DEV & PROD
    @Bean
    public CorsConfigurationSource corsConfigurationSource() {
        CorsConfiguration configuration = new CorsConfiguration();
        configuration.setAllowedOrigins(List.of("*"));
        configuration.setAllowedMethods(List.of("GET", "POST", "PUT", "DELETE", "OPTIONS", "PATCH"));
        configuration.setAllowedHeaders(List.of("*"));

        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", configuration);
        return source;
    }

    // Các Bean dùng chung này LUÔN CÓ MẶT ở mọi môi trường
    @Bean
    public AuthenticationProvider authenticationProvider() {
        DaoAuthenticationProvider provider = new DaoAuthenticationProvider(customUserDetailsService);
        provider.setPasswordEncoder(passwordEncoder());
        return provider;
    }

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }

    @Bean
    public AuthenticationManager authenticationManager(AuthenticationConfiguration config) throws Exception {
        return config.getAuthenticationManager();
    }
}
