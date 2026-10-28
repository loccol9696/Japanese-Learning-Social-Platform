package com.jlsp.backend;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.boot.test.context.SpringBootTest;

/**
 * Kiểm tra toàn bộ ứng dụng khởi động được. Cần PostgreSQL và Redis thật nên chỉ chạy khi bật
 * rõ ràng bằng biến môi trường {@code JLSP_INTEGRATION_TESTS=true} (kèm DB_URL, JWT_SECRET...).
 * Socket.IO bị tắt để không tranh cổng với backend đang chạy.
 */
@SpringBootTest(properties = "socketio.enabled=false")
@EnabledIfEnvironmentVariable(named = "JLSP_INTEGRATION_TESTS", matches = "true")
class BackendApplicationTests {

	@Test
	void contextLoads() {
	}

}
