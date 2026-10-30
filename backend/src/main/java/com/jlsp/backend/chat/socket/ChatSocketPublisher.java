package com.jlsp.backend.chat.socket;

import com.corundumstudio.socketio.SocketIOServer;
import com.jlsp.backend.chat.event.ConversationReadEvent;
import com.jlsp.backend.chat.event.MessageCreatedEvent;
import com.jlsp.backend.chat.event.MessageRecalledEvent;
import lombok.RequiredArgsConstructor;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;
import tools.jackson.databind.ObjectMapper;

import java.util.Map;

/**
 * Đẩy sự kiện chat tới room "user:{id}" của từng người (mọi thiết bị đang mở app).
 * Chỉ phát sau khi transaction commit để client không nhận tin chưa được lưu.
 */
@Component
@ConditionalOnProperty(name = "socketio.enabled", havingValue = "true", matchIfMissing = true)
@RequiredArgsConstructor
public class ChatSocketPublisher {

    public static final String EVENT_MESSAGE_NEW = "message:new";
    public static final String EVENT_MESSAGE_RECALLED = "message:recalled";
    public static final String EVENT_MESSAGE_READ = "message:read";
    public static final String EVENT_TYPING = "typing";

    private final SocketIOServer server;
    private final ObjectMapper objectMapper;

    public static String userRoom(Long userId) {
        return "user:" + userId;
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT, fallbackExecution = true)
    public void onMessageCreated(MessageCreatedEvent event) {
        Object payload = toPayload(event.message());
        emit(event.senderId(), EVENT_MESSAGE_NEW, payload);
        emit(event.recipientId(), EVENT_MESSAGE_NEW, payload);
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT, fallbackExecution = true)
    public void onMessageRecalled(MessageRecalledEvent event) {
        Object payload = toPayload(event.message());
        emit(event.senderId(), EVENT_MESSAGE_RECALLED, payload);
        emit(event.recipientId(), EVENT_MESSAGE_RECALLED, payload);
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT, fallbackExecution = true)
    public void onConversationRead(ConversationReadEvent event) {
        Object payload = toPayload(event.receipt());
        emit(event.otherUserId(), EVENT_MESSAGE_READ, payload);
        emit(event.receipt().getUserId(), EVENT_MESSAGE_READ, payload);
    }

    public void emit(Long userId, String event, Object payload) {
        server.getRoomOperations(userRoom(userId)).sendEvent(event, payload);
    }

    /**
     * Chuyển DTO sang Map bằng ObjectMapper của Spring để JSON qua socket giống hệt
     * REST (vd. LocalDateTime dạng chuỗi ISO), không phụ thuộc Jackson của netty-socketio.
     */
    public Object toPayload(Object dto) {
        return dto == null ? null : objectMapper.convertValue(dto, Map.class);
    }
}
