package com.jlsp.backend.chat.service;

import com.jlsp.backend.common.exception.AppException;
import org.springframework.stereotype.Component;

import java.util.ArrayDeque;
import java.util.Deque;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.function.LongSupplier;

/**
 * Giới hạn tốc độ gửi tin theo cửa sổ trượt, đếm trong bộ nhớ nên mỗi instance server tính riêng
 * (chạy nhiều instance thì mỗi instance cho phép đủ ngưỡng).
 *
 * <p>Bộ đếm của người đã ngừng gửi được dọn định kỳ: trước đây mỗi người từng gửi tin giữ lại một hàng đợi vĩnh
 * viễn, bộ nhớ chỉ tăng theo số người dùng.
 */
@Component
public class ChatRateLimiter {

    private static final int MAX_MESSAGES = 20;
    private static final long WINDOW_MS = 10_000;

    private final int maxMessages;
    private final long windowMs;
    private final LongSupplier clock;
    private final Map<Long, Deque<Long>> sentAt = new ConcurrentHashMap<>();
    private volatile long lastSweepAt;

    public ChatRateLimiter() {
        this(MAX_MESSAGES, WINDOW_MS, System::currentTimeMillis);
    }

    /** Cho phép test chỉnh ngưỡng, cửa sổ và đồng hồ. */
    ChatRateLimiter(int maxMessages, long windowMs, LongSupplier clock) {
        this.maxMessages = maxMessages;
        this.windowMs = windowMs;
        this.clock = clock;
    }

    public void check(Long userId) {
        long now = clock.getAsLong();
        sweepIfDue(now);
        Deque<Long> times = sentAt.computeIfAbsent(userId, id -> new ArrayDeque<>());
        synchronized (times) {
            while (!times.isEmpty() && now - times.peekFirst() > windowMs) {
                times.pollFirst();
            }
            if (times.size() >= maxMessages) {
                throw new AppException(429, "Bạn gửi tin quá nhanh, vui lòng chậm lại");
            }
            times.addLast(now);
        }
    }

    /** Mỗi cửa sổ một lần: bỏ các hàng đợi của người không còn tin nào trong cửa sổ hiện tại. */
    private void sweepIfDue(long now) {
        if (now - lastSweepAt < windowMs) {
            return;
        }
        lastSweepAt = now;
        sentAt.entrySet().removeIf(entry -> {
            Deque<Long> times = entry.getValue();
            synchronized (times) {
                return times.isEmpty() || now - times.peekLast() > windowMs;
            }
        });
    }

    /** Số người đang được theo dõi (để kiểm tra việc dọn bộ nhớ). */
    int trackedUsers() {
        return sentAt.size();
    }
}
