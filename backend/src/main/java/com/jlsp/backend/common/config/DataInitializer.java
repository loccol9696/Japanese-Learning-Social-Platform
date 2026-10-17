package com.jlsp.backend.common.config;

import com.jlsp.backend.user.entity.JLPTLevel;
import com.jlsp.backend.user.entity.User;
import com.jlsp.backend.user.entity.UserRole;
import com.jlsp.backend.user.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.CommandLineRunner;
import org.springframework.stereotype.Component;

import java.time.LocalDateTime;
import java.util.List;

/**
 * Khởi tạo dữ liệu mẫu người dùng (Admin, Creators, Learner) khi ứng dụng chạy lần đầu.
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class DataInitializer implements CommandLineRunner {

    private final UserRepository userRepository;

    // BCrypt hash của mật khẩu "password123"
    private static final String DEFAULT_PASSWORD_HASH = "$2a$10$N.zmdr9k7uOCQb376NoUnuTJ8iAt6Z5EHsM8lE9lBOsl7iKTVKIUi";

    @Override
    public void run(String... args) {

        if (userRepository.count() > 0) {
            log.info("Dữ liệu người dùng đã tồn tại trong database (tổng cộng {} users), bỏ qua bước khởi tạo.",
                    userRepository.count());
            return;
        }

        log.info("Bắt đầu khởi tạo dữ liệu mẫu cho Admin và các User...");

        User admin = User.builder()
                .username("admin")
                .email("admin@jlsp.com")
                .passwordHash(DEFAULT_PASSWORD_HASH) // password123
                .displayName("Hệ thống Quản trị (Admin)")
                .avatarUrl("https://picsum.photos/seed/admin88/200/200")
                .role(UserRole.ADMIN)
                .jlptLevel(JLPTLevel.N1)
                .bio("Tài khoản quản trị viên hệ thống JLSP")
                .isActive(true)
                .createdAt(LocalDateTime.now())
                .updatedAt(LocalDateTime.now())
                .build();

        User creatorTanaka = User.builder()
                .username("tanaka_sensei")
                .email("tanaka@jlsp.com")
                .passwordHash(DEFAULT_PASSWORD_HASH) // password123
                .displayName("Tanaka Sensei")
                .avatarUrl("https://picsum.photos/seed/tanaka/200/200")
                .role(UserRole.USER)
                .jlptLevel(JLPTLevel.N1)
                .bio("Giáo viên tiếng Nhật Tokyo, 10 năm kinh nghiệm luyện thi JLPT N2 - N1")
                .isActive(true)
                .createdAt(LocalDateTime.now())
                .updatedAt(LocalDateTime.now())
                .build();

        User creatorYamada = User.builder()
                .username("yamada_kaiwa")
                .email("yamada@jlsp.com")
                .passwordHash(DEFAULT_PASSWORD_HASH) // password123
                .displayName("Yamada Kaiwa")
                .avatarUrl("https://picsum.photos/seed/yamada/200/200")
                .role(UserRole.USER)
                .jlptLevel(JLPTLevel.N2)
                .bio("Chia sẻ hội thoại tiếng Nhật giao tiếp đời sống thực tế hàng ngày")
                .isActive(true)
                .createdAt(LocalDateTime.now())
                .updatedAt(LocalDateTime.now())
                .build();

        User learnerSakura = User.builder()
                .username("sakura_learner")
                .email("sakura@jlsp.com")
                .passwordHash(DEFAULT_PASSWORD_HASH) // password123
                .displayName("Sakura Chan")
                .avatarUrl("https://picsum.photos/seed/sakura/200/200")
                .role(UserRole.USER)
                .jlptLevel(JLPTLevel.N5)
                .bio("Người mới bắt đầu học tiếng Nhật! Mục tiêu đỗ JLPT N4 năm nay")
                .isActive(true)
                .createdAt(LocalDateTime.now())
                .updatedAt(LocalDateTime.now())
                .build();

        userRepository.saveAll(List.of(admin, creatorTanaka, creatorYamada, learnerSakura));
        log.info("==================================================================");
        log.info("Đã khởi tạo thành công 4 tài khoản mẫu vào database (Mật khẩu: password123):");
        log.info("  1. Admin:   admin          / password123 (Role: ADMIN)");
        log.info("  2. Creator: tanaka_sensei  / password123 (Role: USER)");
        log.info("  3. Creator: yamada_kaiwa   / password123 (Role: USER)");
        log.info("  4. Learner: sakura_learner / password123 (Role: USER)");
        log.info("==================================================================");
    }
}
