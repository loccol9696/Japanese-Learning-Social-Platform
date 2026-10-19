package com.jlsp.backend.common.security.jwt;

import com.jlsp.backend.common.security.ActiveSessionRegistry;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.web.authentication.WebAuthenticationDetailsSource;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;

@Component
public class JwtAuthenticationFilter extends OncePerRequestFilter {

    private final JwtUtils jwtUtils;
    private final ActiveSessionRegistry activeSessionRegistry;

    public JwtAuthenticationFilter(JwtUtils jwtUtils, ActiveSessionRegistry activeSessionRegistry) {
        this.jwtUtils = jwtUtils;
        this.activeSessionRegistry = activeSessionRegistry;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest req, HttpServletResponse resp, FilterChain filterChain)
            throws ServletException, IOException {

        String authHeader = req.getHeader("Authorization");

        if (authHeader != null && authHeader.startsWith("Bearer ")) {
            String token = authHeader.substring(7);
            if (jwtUtils.validateToken(token) && SecurityContextHolder.getContext().getAuthentication() == null) {
                String username = jwtUtils.extractUsername(token);
                if (!activeSessionRegistry.isActive(username, token)) {
                    resp.sendError(HttpServletResponse.SC_UNAUTHORIZED,
                            "Phiên đăng nhập đã hết hạn hoặc tài khoản đang được dùng ở nơi khác");
                    return;
                }
                var authorities = jwtUtils.extractRoles(token).stream()
                        .map(SimpleGrantedAuthority::new)
                        .toList();

                var authToken = new UsernamePasswordAuthenticationToken(username, null, authorities);
                authToken.setDetails(new WebAuthenticationDetailsSource().buildDetails(req));
                SecurityContextHolder.getContext().setAuthentication(authToken);
            }
        }

        filterChain.doFilter(req, resp);
    }
}
