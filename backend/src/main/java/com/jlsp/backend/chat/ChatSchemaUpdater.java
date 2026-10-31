package com.jlsp.backend.chat;

import lombok.RequiredArgsConstructor;
import org.springframework.boot.CommandLineRunner;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

/**
 * Hibernate tạo CHECK theo danh sách enum lúc tạo bảng và ddl-auto=update không cập nhật lại,
 * nên bảng messages có sẵn sẽ từ chối loại tin mới (IMAGE) với lỗi 500. Enum đã được Java
 * kiểm soát nên bỏ hẳn CHECK này.
 */
@Component
@RequiredArgsConstructor
public class ChatSchemaUpdater implements CommandLineRunner {

    private final JdbcTemplate jdbcTemplate;

    @Override
    public void run(String... args) {
        jdbcTemplate.execute("ALTER TABLE messages DROP CONSTRAINT IF EXISTS messages_type_check");
    }
}
