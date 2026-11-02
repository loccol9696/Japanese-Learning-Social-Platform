package com.jlsp.backend.report;

import lombok.RequiredArgsConstructor;
import org.springframework.boot.CommandLineRunner;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

/**
 * Hibernate tạo CHECK theo danh sách enum lúc tạo bảng và ddl-auto=update không cập nhật lại, nên bảng
 * reports có sẵn sẽ từ chối loại đối tượng, lý do và hành động mới. Enum đã được Java kiểm soát nên bỏ
 * hẳn các CHECK này.
 */
@Component
@RequiredArgsConstructor
public class ReportSchemaUpdater implements CommandLineRunner {

    private final JdbcTemplate jdbcTemplate;

    @Override
    public void run(String... args) {
        jdbcTemplate.execute("ALTER TABLE reports DROP CONSTRAINT IF EXISTS reports_target_type_check");
        jdbcTemplate.execute("ALTER TABLE reports DROP CONSTRAINT IF EXISTS reports_reason_check");
        jdbcTemplate.execute("ALTER TABLE reports DROP CONSTRAINT IF EXISTS reports_action_check");
    }
}
