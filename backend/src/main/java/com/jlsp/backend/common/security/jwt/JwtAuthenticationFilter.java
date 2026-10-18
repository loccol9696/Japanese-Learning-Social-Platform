package com.jlsp.backend.common.security.jwt;

import com.jlsp.backend.common.security.CustomUserDetailsService;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.security.web.authentication.WebAuthenticationDetailsSource;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;

@Component
public class JwtAuthenticationFilter extends OncePerRequestFilter {

    private final JwtUtils jwtUtils;
    private final CustomUserDetailsService userDetailsService;

    // Đã xóa SecurityFilterChain khỏi constructor để tránh Circular Dependency
    public JwtAuthenticationFilter(JwtUtils jwtUtils, CustomUserDetailsService userDetailsService) {
        this.jwtUtils = jwtUtils;
        this.userDetailsService = userDetailsService;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest req, HttpServletResponse resp, FilterChain filterChain)
            throws ServletException, IOException {

        String authHeader = req.getHeader("Authorization");

        if (authHeader != null && authHeader.startsWith("Bearer ")) {
            String token = authHeader.substring(7);
            if (jwtUtils.validateToken(token) && SecurityContextHolder.getContext().getAuthentication() == null) {
                authenticate(jwtUtils.extractUsername(token), req);
            }
        }

        filterChain.doFilter(req, resp);
    }

    /**
     * Nạp lại user từ DB để principal là CustomUserDetails (dùng được với CurrentUser /
     * @AuthenticationPrincipal), role luôn mới nhất và tài khoản bị khóa không đăng nhập được.
     */
    private void authenticate(String username, HttpServletRequest req) {
        UserDetails userDetails;
        try {
            userDetails = userDetailsService.loadUserByUsername(username);
        } catch (UsernameNotFoundException e) {
            return;
        }
        if (!userDetails.isEnabled()) {
            return;
        }

        var authToken = new UsernamePasswordAuthenticationToken(
                userDetails, null, userDetails.getAuthorities());
        authToken.setDetails(new WebAuthenticationDetailsSource().buildDetails(req));
        SecurityContextHolder.getContext().setAuthentication(authToken);
    }
}
