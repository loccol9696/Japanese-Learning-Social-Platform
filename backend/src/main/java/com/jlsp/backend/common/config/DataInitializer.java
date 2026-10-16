package com.jlsp.backend.common.config;

import com.jlsp.backend.user.entity.JLPTLevel;
import com.jlsp.backend.user.entity.User;
import com.jlsp.backend.user.entity.UserRole;
import com.jlsp.backend.user.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.crypto.password.PasswordEncoder;

@Configuration
@RequiredArgsConstructor
@Slf4j
public class DataInitializer implements CommandLineRunner {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;

    @Override
    public void run(String... args) {
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
