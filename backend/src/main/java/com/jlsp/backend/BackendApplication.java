package com.jlsp.backend;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableAsync;
import org.springframework.scheduling.annotation.EnableScheduling;

import java.util.TimeZone;

@SpringBootApplication
@EnableAsync
@EnableScheduling
public class BackendApplication {

	public static void main(String[] args) {
		// Thời gian lưu bằng LocalDateTime (không kèm múi giờ) và app hiển thị nguyên giá trị đó,
		// nên server phải chạy theo giờ Việt Nam kể cả trong container mặc định UTC.
		TimeZone.setDefault(TimeZone.getTimeZone("Asia/Ho_Chi_Minh"));
		SpringApplication.run(BackendApplication.class, args);
	}

}
