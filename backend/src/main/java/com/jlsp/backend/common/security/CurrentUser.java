package com.jlsp.backend.common.security;

import com.jlsp.backend.common.constant.ErrorCode;
import com.jlsp.backend.common.exception.AppException;
import com.jlsp.backend.user.entity.User;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;

import java.util.Optional;

/**
 * Lấy người dùng hiện tại từ JWT (do {@code JwtAuthenticationFilter} nạp vào SecurityContext).
 * Không bao giờ tin ID do client gửi lên (header / query param / body).
 */
public final class CurrentUser {

    private CurrentUser() {
    }

    public static Optional<User> find() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth != null && auth.getPrincipal() instanceof CustomUserDetails details) {
            return Optional.of(details.getUser());
        }
        return Optional.empty();
    }

    /** ID người xem nếu đã đăng nhập, null nếu là khách (dùng cho endpoint đọc công khai). */
    public static Long idOrNull() {
        return find().map(User::getId).orElse(null);
    }

    /** ID người dùng hiện tại; ném 401 nếu chưa đăng nhập. */
    public static Long requireId() {
        return require().getId();
    }

    public static User require() {
        return find().orElseThrow(() -> new AppException(ErrorCode.UNAUTHORIZED));
    }
}
