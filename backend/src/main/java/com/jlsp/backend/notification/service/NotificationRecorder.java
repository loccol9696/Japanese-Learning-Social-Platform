package com.jlsp.backend.notification.service;

import com.jlsp.backend.notification.event.NotificationRequestedEvent;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

/**
 * Lưu thông báo sau khi nghiệp vụ gốc commit, chạy ở luồng riêng. Lỗi ở đây chỉ được ghi log,
 * không bao giờ ảnh hưởng thao tác của người dùng.
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class NotificationRecorder {

    private final NotificationService notificationService;

    @Async
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT, fallbackExecution = true)
    public void onNotificationRequested(NotificationRequestedEvent event) {
        try {
            notificationService.record(event);
        } catch (Exception e) {
            log.warn("Không tạo được thông báo {} cho user {}: {}", event.type(), event.recipientId(), e.getMessage());
        }
    }
}
