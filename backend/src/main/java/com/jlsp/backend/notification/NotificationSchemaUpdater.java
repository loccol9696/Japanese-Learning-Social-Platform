package com.jlsp.backend.notification;

import lombok.RequiredArgsConstructor;
import org.springframework.boot.CommandLineRunner;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

/**
 * Hibernate tạo CHECK theo danh sách enum lúc tạo bảng và ddl-auto=update không cập nhật lại,
 * nên khi thêm loại thông báo mới (vd. báo cáo vi phạm) bảng có sẵn sẽ từ chối với lỗi 500.
 * Enum đã được Java kiểm soát nên bỏ hẳn CHECK này, giống {@code ChatSchemaUpdater}.
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
