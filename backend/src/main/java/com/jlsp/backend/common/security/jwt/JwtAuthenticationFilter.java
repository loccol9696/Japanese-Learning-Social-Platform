package com.jlsp.backend.common.security.jwt;

import com.jlsp.backend.common.security.AuthUser;
import com.jlsp.backend.common.security.token.AccessTokenDenylist;
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

/**
 * Đọc "Authorization: Bearer ..." và gắn {@link AuthUser} vào SecurityContext.
 * Token thiếu/sai/hết hạn/đã thu hồi thì request đi tiếp như khách: API công khai
 * vẫn chạy, API cần đăng nhập sẽ bị entry point trả 401 JSON.
 */
@Component
public class JwtAuthenticationFilter extends OncePerRequestFilter {

    private static final String BEARER_PREFIX = "Bearer ";

    private final JwtUtils jwtUtils;
    private final AccessTokenDenylist denylist;

    public JwtAuthenticationFilter(JwtUtils jwtUtils, AccessTokenDenylist denylist) {
        this.jwtUtils = jwtUtils;
        this.denylist = denylist;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest req, HttpServletResponse resp, FilterChain filterChain)
            throws ServletException, IOException {

        String authHeader = req.getHeader("Authorization");
        if (authHeader != null && authHeader.startsWith(BEARER_PREFIX)
                && SecurityContextHolder.getContext().getAuthentication() == null) {

            jwtUtils.parse(authHeader.substring(BEARER_PREFIX.length()))
                    .filter(claims -> !denylist.isDenied(claims.tokenId()))
                    .ifPresent(claims -> {
                        AuthUser principal = new AuthUser(claims.userId(), claims.username(), claims.roles());
                        var authorities = claims.roles().stream().map(SimpleGrantedAuthority::new).toList();
                        var authToken = new UsernamePasswordAuthenticationToken(principal, null, authorities);
                        authToken.setDetails(new WebAuthenticationDetailsSource().buildDetails(req));
                        SecurityContextHolder.getContext().setAuthentication(authToken);
                    });
        }

        filterChain.doFilter(req, resp);
    }
}
