package com.jlsp.backend.common.security.ratelimit;

import jakarta.servlet.http.HttpServletRequest;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/**
 * Xác định địa chỉ IP của client cho giới hạn tần suất và chống đếm lặp.
 *
 * <p>Mặc định lấy IP của kết nối trực tiếp. Chỉ khi chạy sau reverse proxy đáng tin mới đặt
 * {@code TRUST_FORWARDED_FOR=true} để dùng {@code X-Forwarded-For}; nếu không, mọi người dùng chung một IP
 * của proxy, còn nếu bật mà không có proxy thì kẻ tấn công tự giả IP bằng header.
 */
@Component
public class ClientIpResolver {

    private final boolean trustForwardedFor;

    public ClientIpResolver(@Value("${TRUST_FORWARDED_FOR:false}") boolean trustForwardedFor) {
        this.trustForwardedFor = trustForwardedFor;
    }

    public String resolve(HttpServletRequest request) {
        if (trustForwardedFor) {
            String forwarded = request.getHeader("X-Forwarded-For");
            if (forwarded != null && !forwarded.isBlank()) {
                // Phần tử đầu là client gốc; các phần tử sau là các proxy trung gian.
                return forwarded.split(",")[0].trim();
            }
        }
        return request.getRemoteAddr();
    }
}
