package com.jlsp.backend.chat.service;

import com.jlsp.backend.common.exception.AppException;
import org.springframework.stereotype.Component;

import java.util.ArrayDeque;
import java.util.Deque;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Giới hạn tốc độ gửi tin theo cửa sổ trượt (trong bộ nhớ, đủ cho một instance server).
 */
@Component
public class ChatRateLimiter {

    private static final int MAX_MESSAGES = 20;
    private static final long WINDOW_MS = 10_000;

    private final Map<Long, Deque<Long>> sentAt = new ConcurrentHashMap<>();

    public void check(Long userId) {
        long now = System.currentTimeMillis();
        Deque<Long> times = sentAt.computeIfAbsent(userId, id -> new ArrayDeque<>());
        synchronized (times) {
            while (!times.isEmpty() && now - times.peekFirst() > WINDOW_MS) {
                times.pollFirst();
            }
            if (times.size() >= MAX_MESSAGES) {
                throw new AppException(429, "Bạn gửi tin quá nhanh, vui lòng chậm lại");
            }
            times.addLast(now);
        }
    }
}
