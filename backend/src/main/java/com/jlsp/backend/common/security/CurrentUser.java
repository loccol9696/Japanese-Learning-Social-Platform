package com.jlsp.backend.common.security;

import com.jlsp.backend.common.exception.AppException;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;

import java.util.Optional;

/**
 * Nơi DUY NHẤT để controller/service biết "ai đang gọi API".
 * Danh tính chỉ lấy từ access token đã được {@code JwtAuthenticationFilter}
 * kiểm tra — không bao giờ lấy từ header X-User-Id hay tham số do client gửi.
 */
public final class CurrentUser {

    private CurrentUser() {
    }

    public static Optional<AuthUser> get() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth != null && auth.getPrincipal() instanceof AuthUser user) {
            return Optional.of(user);
        }
        return Optional.empty();
    }

    /** ID người dùng nếu đã đăng nhập, ngược lại null (dùng cho API công khai). */
    public static Long idOrNull() {
        return get().map(AuthUser::id).orElse(null);
    }

    /** ID người dùng; ném 401 nếu chưa đăng nhập. */
    public static Long requireId() {
        return require().id();
    }

    public static AuthUser require() {
        return get().orElseThrow(() -> new AppException(401, "Vui lòng đăng nhập để tiếp tục"));
    }
}
