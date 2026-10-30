package com.jlsp.backend.notification.push;

import com.jlsp.backend.chat.push.FcmClient;
import com.jlsp.backend.chat.repository.DeviceTokenRepository;
import com.jlsp.backend.notification.dto.response.NotificationResponse;
import com.jlsp.backend.notification.entity.NotificationType;
import com.jlsp.backend.notification.event.NotificationCreatedEvent;
import lombok.RequiredArgsConstructor;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

import java.time.Duration;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Báo thông báo mới tới máy người nhận qua FCM. Lượt thích đến dồn dập nên chỉ đẩy tối đa một
 * lần mỗi {@link #LIKE_PUSH_INTERVAL} cho mỗi video; thông báo vẫn nằm đủ trong danh sách.
 */
@Component
@RequiredArgsConstructor
public class NotificationPushNotifier {

    static final Duration LIKE_PUSH_INTERVAL = Duration.ofMinutes(10);
    private static final int MAX_PREVIEW_LENGTH = 120;
    private static final int PRUNE_THRESHOLD = 5_000;

    private final FcmClient fcmClient;
    private final DeviceTokenRepository deviceTokenRepository;

    /** recipient:video → thời điểm (ms) đẩy lượt thích gần nhất. */
    private final Map<String, Long> lastLikePush = new ConcurrentHashMap<>();

    @Async
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT, fallbackExecution = true)
    public void onNotificationCreated(NotificationCreatedEvent event) {
        if (!fcmClient.isEnabled()) {
            return;
        }
        NotificationResponse notification = event.notification();
        if (isThrottledLike(event.recipientId(), notification, System.currentTimeMillis())) {
            return;
        }
        List<String> tokens = deviceTokenRepository.findTokensByUserId(event.recipientId());
        if (tokens.isEmpty()) {
            return;
        }
        String title = title(notification);
        String body = body(notification);
        Map<String, String> data = data(notification);
        for (String token : tokens) {
            if (fcmClient.send(token, title, body, data) == FcmClient.Result.TOKEN_INVALID) {
                deviceTokenRepository.deleteByToken(token);
            }
        }
    }

    boolean isThrottledLike(Long recipientId, NotificationResponse notification, long nowMs) {
        if (notification.getType() != NotificationType.VIDEO_LIKED) {
            return false;
        }
        if (lastLikePush.size() > PRUNE_THRESHOLD) {
            long cutoff = nowMs - LIKE_PUSH_INTERVAL.toMillis();
            lastLikePush.values().removeIf(sentAt -> sentAt < cutoff);
        }
        String key = recipientId + ":" + notification.getVideoId();
        long[] sentNow = {0};
        lastLikePush.compute(key, (k, last) -> {
            if (last != null && nowMs - last < LIKE_PUSH_INTERVAL.toMillis()) {
                return last;
            }
            sentNow[0] = 1;
            return nowMs;
        });
        return sentNow[0] == 0;
    }

    static String title(NotificationResponse n) {
        return switch (n.getType()) {
            case VIDEO_APPROVED -> "Video đã được duyệt";
            case VIDEO_REJECTED -> "Video bị từ chối";
            default -> n.getActorName() == null ? "Thông báo mới" : n.getActorName();
        };
    }

    static String body(NotificationResponse n) {
        return switch (n.getType()) {
            case VIDEO_COMMENTED -> "đã bình luận: " + preview(n.getDetail());
            case VIDEO_LIKED -> "đã thích video của bạn";
            case VIDEO_SHARED -> "đã chia sẻ video của bạn";
            case VIDEO_APPROVED -> videoLabel(n) + " đã được đăng công khai";
            case VIDEO_REJECTED -> {
                String reason = preview(n.getDetail());
                yield reason.isEmpty() ? videoLabel(n) : videoLabel(n) + ": " + reason;
            }
        };
    }

    static Map<String, String> data(NotificationResponse n) {
        Map<String, String> data = new HashMap<>();
        data.put("notificationId", String.valueOf(n.getId()));
        data.put("type", n.getType().name());
        if (n.getVideoId() != null) {
            data.put("videoId", String.valueOf(n.getVideoId()));
        }
        if (n.getCommentId() != null) {
            data.put("commentId", String.valueOf(n.getCommentId()));
        }
        return data;
    }

    private static String videoLabel(NotificationResponse n) {
        return n.getVideoTitle() == null || n.getVideoTitle().isBlank() ? "Video của bạn" : n.getVideoTitle();
    }

    private static String preview(String text) {
        if (text == null) {
            return "";
        }
        return text.length() <= MAX_PREVIEW_LENGTH ? text : text.substring(0, MAX_PREVIEW_LENGTH) + "…";
    }
}
