package com.jlsp.backend.notification.socket;

import com.jlsp.backend.chat.socket.ChatSocketPublisher;
import com.jlsp.backend.notification.event.NotificationCreatedEvent;
import lombok.RequiredArgsConstructor;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

/**
 * Đẩy thông báo mới tới room "user:{id}" của người nhận trên cùng server Socket.IO với chat.
 * Chỉ phát sau khi transaction commit để client không nhận thông báo chưa được lưu.
 */
@Component
@ConditionalOnProperty(name = "socketio.enabled", havingValue = "true", matchIfMissing = true)
@RequiredArgsConstructor
public class NotificationSocketPublisher {

    public static final String EVENT_NOTIFICATION_NEW = "notification:new";

    private final ChatSocketPublisher socketPublisher;

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT, fallbackExecution = true)
    public void onNotificationCreated(NotificationCreatedEvent event) {
        socketPublisher.emit(event.recipientId(), EVENT_NOTIFICATION_NEW,
                socketPublisher.toPayload(event.notification()));
    }
}
