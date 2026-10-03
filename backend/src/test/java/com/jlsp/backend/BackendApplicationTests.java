package com.jlsp.backend;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;

import java.util.TimeZone;

@SpringBootTest
class BackendApplicationTests {

	static {
		System.setProperty("user.timezone", "Asia/Ho_Chi_Minh");
		TimeZone.setDefault(TimeZone.getTimeZone("Asia/Ho_Chi_Minh"));
	}

	@Test
	void contextLoads() {
	}

}

