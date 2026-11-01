package com.jlsp.backend.notification;

import lombok.RequiredArgsConstructor;
import org.springframework.boot.CommandLineRunner;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

/**
 * Hibernate tạo CHECK theo danh sách enum lúc tạo bảng và ddl-auto=update không cập nhật lại, nên bảng
 * notifications có sẵn sẽ từ chối loại thông báo mới (COMMENT_LIKED...). NotificationService nuốt lỗi
 * khi tạo thông báo nên việc từ chối này sẽ mất thông báo trong im lặng. Enum đã được Java kiểm soát nên
 * bỏ hẳn CHECK này (cùng cách với ChatSchemaUpdater).
 */
@Component
@RequiredArgsConstructor
public class NotificationSchemaUpdater implements CommandLineRunner {

    private final JdbcTemplate jdbcTemplate;

    @Override
    public void run(String... args) {
        jdbcTemplate.execute("ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_type_check");
    }
}
