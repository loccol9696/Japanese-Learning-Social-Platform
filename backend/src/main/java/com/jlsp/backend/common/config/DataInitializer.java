package com.jlsp.backend.common.config;

import com.jlsp.backend.user.entity.JLPTLevel;
import com.jlsp.backend.user.entity.User;
import com.jlsp.backend.user.entity.UserRole;
import com.jlsp.backend.user.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.CommandLineRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

import java.time.LocalDateTime;
import java.util.List;

@Component
@RequiredArgsConstructor
@Slf4j
public class DataInitializer implements CommandLineRunner {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;

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
                .passwordHash("$2a$10$N.zmdr9k7uOCQb376NoUnuTJ8iAt6Z5EHsM8lE9lBOsl7iKTVKIUi") // password123
                .displayName("Hệ thống Quản trị (Admin)")
                .avatarUrl("https://ik.imagekit.io/jlsp_demo/avatars/admin.png")
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
                .passwordHash("$2a$10$N.zmdr9k7uOCQb376NoUnuTJ8iAt6Z5EHsM8lE9lBOsl7iKTVKIUi") // password123
                .displayName("Tanaka Sensei")
                .avatarUrl("https://ik.imagekit.io/jlsp_demo/avatars/tanaka.png")
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
                .passwordHash("$2a$10$N.zmdr9k7uOCQb376NoUnuTJ8iAt6Z5EHsM8lE9lBOsl7iKTVKIUi") // password123
                .displayName("Yamada Kaiwa")
                .avatarUrl("https://ik.imagekit.io/jlsp_demo/avatars/yamada.png")
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
                .passwordHash("$2a$10$N.zmdr9k7uOCQb376NoUnuTJ8iAt6Z5EHsM8lE9lBOsl7iKTVKIUi") // password123
                .displayName("Sakura Chan")
                .avatarUrl("https://ik.imagekit.io/jlsp_demo/avatars/sakura.png")
                .role(UserRole.USER)
                .jlptLevel(JLPTLevel.N5)
                .bio("Người mới bắt đầu học tiếng Nhật! Mục tiêu đỗ JLPT N4 năm nay")
                .isActive(true)
                .createdAt(LocalDateTime.now())
                .updatedAt(LocalDateTime.now())
                .build();

        userRepository.saveAll(List.of(admin, creatorTanaka, creatorYamada, learnerSakura));
        log.info("Đã khởi tạo thành công 4 tài khoản mẫu: 1 Admin và 3 Users.");

        final String adminUsername = "admin";
        final String adminEmail = "admin@jlsp.edu.vn";
        final String defaultPassword = "AdminPassword123@";

        if (userRepository.existsByUsername(adminUsername)) {
            log.info("Admin account '{}' already exists in the database.", adminUsername);
            return;
        }

        User adminUser = User.builder()
                .username(adminUsername)
                .email(adminEmail)
                .passwordHash(passwordEncoder.encode(defaultPassword))
                .displayName("System Administrator")
                .role(UserRole.ADMIN)
                .jlptLevel(JLPTLevel.N1)
                .isActive(true)
                .bio("Quản trị viên hệ thống JLSP")
                .avatarUrl("https://picsum.photos/seed/admin88/200/200")
                .build();

        userRepository.save(adminUser);
        log.info("======================================================");
        log.info("Successfully seeded ADMIN account into database!");
        log.info("Username: {}", adminUsername);
        log.info("Password: {}", defaultPassword);
        log.info("Email:    {}", adminEmail);
        log.info("Role:     {}", UserRole.ADMIN);
        log.info("======================================================");
    }
}
