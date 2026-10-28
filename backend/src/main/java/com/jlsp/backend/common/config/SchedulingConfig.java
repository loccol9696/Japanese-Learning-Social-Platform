package com.jlsp.backend.common.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.EnableScheduling;

/** Bật các tác vụ chạy định kỳ ({@code @Scheduled}), ví dụ dọn thông báo cũ. */
@Configuration
@EnableScheduling
public class SchedulingConfig {
}
