package com.jlsp.backend.chat.push;

import com.jlsp.backend.chat.dto.response.MessageResponse;
import com.jlsp.backend.chat.entity.MessageType;
import com.jlsp.backend.chat.event.MessageCreatedEvent;
import com.jlsp.backend.chat.repository.DeviceTokenRepository;
import com.jlsp.backend.user.entity.User;
import com.jlsp.backend.user.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

import java.util.List;
import java.util.Map;

/**
 * Báo tin mới tới máy người nhận. Luôn gửi, không xét người nhận có đang kết nối socket hay
 * không: socket có thể còn sống một lúc sau khi app vào nền, còn lúc app đang mở thì hệ
 * thống không hiện thông báo FCM.
 */
@Component
@RequiredArgsConstructor
public class ChatPushNotifier {

    private static final int MAX_PREVIEW_LENGTH = 120;

    private final FcmClient fcmClient;
    private final DeviceTokenRepository deviceTokenRepository;
    private final UserRepository userRepository;

    @Async
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT, fallbackExecution = true)
    public void onMessageCreated(MessageCreatedEvent event) {
        if (!fcmClient.isEnabled()) {
            return;
        }
        List<String> tokens = deviceTokenRepository.findTokensByUserId(event.recipientId());
        if (tokens.isEmpty()) {
            return;
        }
        String title = userRepository.findById(event.senderId())
                .map(ChatPushNotifier::displayName)
                .orElse("Tin nhắn mới");
        MessageResponse message = event.message();
        Map<String, String> data = Map.of(
                "conversationId", String.valueOf(message.getConversationId()),
                "messageId", String.valueOf(message.getId()));

        for (String token : tokens) {
            if (fcmClient.send(token, title, preview(message), data) == FcmClient.Result.TOKEN_INVALID) {
                deviceTokenRepository.deleteByToken(token);
            }
        }
    }

    private static String displayName(User user) {
        String name = user.getDisplayName();
        return name == null || name.isBlank() ? user.getUsername() : name;
    }

    private static String preview(MessageResponse message) {
        if (message.getType() == MessageType.VIDEO_SHARE) {
            return "🎬 Đã chia sẻ một video";
        }
        if (message.getType() == MessageType.IMAGE) {
            return "📷 Đã gửi một ảnh";
        }
        String content = message.getContent();
        return content.length() <= MAX_PREVIEW_LENGTH ? content : content.substring(0, MAX_PREVIEW_LENGTH) + "…";
    }
}
