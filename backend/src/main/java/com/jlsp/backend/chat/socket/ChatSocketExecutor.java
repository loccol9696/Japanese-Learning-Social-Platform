package com.jlsp.backend.chat.socket;

import jakarta.annotation.PreDestroy;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

import java.util.Arrays;
import java.util.concurrent.ArrayBlockingQueue;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.RejectedExecutionException;
import java.util.concurrent.ThreadPoolExecutor;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * Chạy xử lý event socket ngoài luồng Netty để truy vấn DB chậm không làm kẹt các kết nối
 * dùng chung luồng đó. Mỗi user luôn rơi vào cùng một luồng nên tin của một người giữ
 * đúng thứ tự gửi.
 */
@Component
@ConditionalOnProperty(name = "socketio.enabled", havingValue = "true", matchIfMissing = true)
public class ChatSocketExecutor {

    private static final int QUEUE_CAPACITY = 256;

    private final ExecutorService[] workers;

    public ChatSocketExecutor(@Value("${socketio.worker-threads:4}") int threads) {
        AtomicInteger counter = new AtomicInteger();
        workers = new ExecutorService[threads];
        Arrays.setAll(workers, i -> new ThreadPoolExecutor(1, 1, 0, TimeUnit.MILLISECONDS,
                new ArrayBlockingQueue<>(QUEUE_CAPACITY),
                task -> new Thread(task, "chat-socket-" + counter.getAndIncrement())));
    }

    /**
     * @throws RejectedExecutionException khi hàng đợi của user này đã đầy
     */
    public void execute(Long userId, Runnable task) {
        workers[Math.floorMod(userId.hashCode(), workers.length)].execute(task);
    }

    @PreDestroy
    public void shutdown() {
        for (ExecutorService worker : workers) {
            worker.shutdown();
        }
    }
}
