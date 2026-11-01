package com.jlsp.backend.report.event;

/**
 * Tài khoản vừa bị khóa từ một báo cáo vi phạm; phát trong transaction để chỉ gửi mail khi đã khóa thật.
 */
public record AccountLockedEvent(String email, String name, String reason) {
}
