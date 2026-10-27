package com.jlsp.backend.common.config;

import com.jlsp.backend.user.entity.JLPTLevel;
import com.jlsp.backend.user.entity.User;
import com.jlsp.backend.user.entity.UserRole;
import com.jlsp.backend.user.repository.UserRepository;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.env.Environment;
import org.springframework.core.env.Profiles;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

import java.time.LocalDateTime;

/**
 * Tạo tài khoản quản trị đầu tiên khi hệ thống chưa có admin nào.
 *
 * <ul>
 *   <li>Chỉ tạo khi chưa tồn tại tài khoản ADMIN; <b>không bao giờ</b> đặt lại mật khẩu của admin
 *       đã có (trước đây mỗi lần khởi động đều bị ghi đè).</li>
 *   <li>Thông tin lấy từ biến môi trường {@code ADMIN_USERNAME}, {@code ADMIN_EMAIL},
 *       {@code ADMIN_PASSWORD}. Mật khẩu không bao giờ được ghi ra log.</li>
 *   <li>Thiếu {@code ADMIN_PASSWORD}: profile dev dùng mật khẩu mặc định (kèm cảnh báo), các profile
 *       khác bỏ qua và không tạo admin.</li>
 *   <li>Cần khôi phục quyền vào admin: đặt {@code ADMIN_RESET_PASSWORD=true} cùng
 *       {@code ADMIN_PASSWORD}, khởi động một lần rồi bỏ cờ đi.</li>
 * </ul>
 */
@Component
@Slf4j
public class AdminAccountSeeder {

    /** Mật khẩu dự phòng, chỉ dùng ở dev khi ADMIN_PASSWORD chưa khai báo. */
    static final String DEV_FALLBACK_PASSWORD = "AdminPassword123@";
    static final int MIN_PASSWORD_LENGTH = 8;

    public enum Result {
        /** Đã tạo admin mới. */
        CREATED,
        /** Đã có admin, không đổi gì. */
        ALREADY_EXISTS,
        /** Đã đặt lại mật khẩu admin theo yêu cầu rõ ràng (ADMIN_RESET_PASSWORD=true). */
        PASSWORD_RESET,
        /** Không thể tạo (thiếu mật khẩu ở prod, mật khẩu quá ngắn, trùng tên...). */
        SKIPPED
    }

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final Environment environment;
    private final String username;
    private final String email;
    private final String password;
    private final boolean resetPassword;

    public AdminAccountSeeder(
            UserRepository userRepository,
            PasswordEncoder passwordEncoder,
            Environment environment,
            @Value("${ADMIN_USERNAME:admin}") String username,
            @Value("${ADMIN_EMAIL:admin@jlsp.com}") String email,
            @Value("${ADMIN_PASSWORD:}") String password,
            @Value("${ADMIN_RESET_PASSWORD:false}") boolean resetPassword) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.environment = environment;
        this.username = username.trim();
        this.email = email.trim();
        this.password = password == null ? "" : password;
        this.resetPassword = resetPassword;
    }

    public Result seed() {
        boolean dev = environment.acceptsProfiles(Profiles.of("dev"));
        boolean hasPassword = !password.isBlank();

        if (resetPassword) {
            return resetExistingAdmin(hasPassword);
        }
        if (userRepository.countByRole(UserRole.ADMIN) > 0) {
            return Result.ALREADY_EXISTS;
        }

        String rawPassword = password;
        if (!hasPassword) {
            if (!dev) {
                log.warn("Chưa có tài khoản ADMIN và ADMIN_PASSWORD chưa được khai báo: bỏ qua việc tạo admin.");
                return Result.SKIPPED;
            }
            rawPassword = DEV_FALLBACK_PASSWORD;
            log.warn("ADMIN_PASSWORD chưa khai báo: tạo admin '{}' với mật khẩu mặc định của môi trường dev. "
                    + "Hãy đặt ADMIN_PASSWORD trước khi triển khai.", username);
        } else if (rawPassword.length() < MIN_PASSWORD_LENGTH) {
            log.error("ADMIN_PASSWORD phải có ít nhất {} ký tự: bỏ qua việc tạo admin.", MIN_PASSWORD_LENGTH);
            return Result.SKIPPED;
        }

        if (userRepository.existsByUsername(username) || userRepository.existsByEmail(email)) {
            log.warn("Tên '{}' hoặc email '{}' đã được tài khoản khác dùng: không thể tạo admin.", username, email);
            return Result.SKIPPED;
        }

        LocalDateTime now = LocalDateTime.now();
        userRepository.save(User.builder()
                .username(username)
                .email(email)
                .passwordHash(passwordEncoder.encode(rawPassword))
                .displayName("Hệ thống Quản trị (Admin)")
                .role(UserRole.ADMIN)
                .jlptLevel(JLPTLevel.N1)
                .bio("Tài khoản quản trị viên hệ thống JLSP")
                .isActive(true)
                .createdAt(now)
                .updatedAt(now)
                .build());
        log.info("Đã tạo tài khoản admin '{}'.", username);
        return Result.CREATED;
    }

    private Result resetExistingAdmin(boolean hasPassword) {
        if (!hasPassword || password.length() < MIN_PASSWORD_LENGTH) {
            log.error("ADMIN_RESET_PASSWORD=true cần ADMIN_PASSWORD có ít nhất {} ký tự: bỏ qua.", MIN_PASSWORD_LENGTH);
            return Result.SKIPPED;
        }
        return userRepository.findByUsername(username)
                .filter(u -> u.getRole() == UserRole.ADMIN)
                .map(admin -> {
                    admin.setPasswordHash(passwordEncoder.encode(password));
                    admin.setIsActive(true);
                    userRepository.save(admin);
                    log.warn("Đã đặt lại mật khẩu admin '{}' theo ADMIN_RESET_PASSWORD. "
                            + "Hãy bỏ cờ này sau lần khởi động này.", username);
                    return Result.PASSWORD_RESET;
                })
                .orElseGet(() -> {
                    log.warn("Không có tài khoản ADMIN tên '{}' để đặt lại mật khẩu.", username);
                    return Result.SKIPPED;
                });
    }
}
