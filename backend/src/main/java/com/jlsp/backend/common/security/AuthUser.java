package com.jlsp.backend.common.security;

import java.security.Principal;
import java.util.List;

/**
 * Người dùng đã xác thực, dựng từ access token (không truy vấn DB).
 * Là principal trong SecurityContext; implement {@link Principal} để
 * {@code Authentication#getName()} trả về username.
 */
public record AuthUser(Long id, String username, List<String> roles) implements Principal {

    @Override
    public String getName() {
        return username;
    }

    public boolean hasRole(String role) {
        return roles != null && roles.contains("ROLE_" + role);
    }
}
