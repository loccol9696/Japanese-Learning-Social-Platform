package com.jlsp.backend.notification.push;

import com.jlsp.backend.chat.push.FcmClient;
import com.jlsp.backend.chat.repository.DeviceTokenRepository;
import com.jlsp.backend.notification.dto.response.NotificationResponse;
import com.jlsp.backend.notification.entity.NotificationType;
import com.jlsp.backend.notification.event.NotificationCreatedEvent;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

class NotificationPushNotifierTest {

    private static final long RECIPIENT = 1L;

    private FcmClient fcmClient;
    private DeviceTokenRepository deviceTokenRepository;
    private NotificationPushNotifier notifier;

    @BeforeEach
    void setUp() {
        fcmClient = mock(FcmClient.class);
        deviceTokenRepository = mock(DeviceTokenRepository.class);
        notifier = new NotificationPushNotifier(fcmClient, deviceTokenRepository);

        when(fcmClient.isEnabled()).thenReturn(true);
        when(deviceTokenRepository.findTokensByUserId(RECIPIENT)).thenReturn(List.of("token-a"));
        when(fcmClient.send(anyString(), anyString(), anyString(), any())).thenReturn(FcmClient.Result.SENT);
    }

    @Test
    void doesNothingWhenFcmIsNotConfigured() {
        when(fcmClient.isEnabled()).thenReturn(false);

        notifier.onNotificationCreated(event(commented("hay quá")));

        verifyNoInteractions(deviceTokenRepository);
    }

    @Test
    void commentPushCarriesActorNamePreviewAndTargets() {
        notifier.onNotificationCreated(event(commented("hay quá")));

        verify(fcmClient).send("token-a", "Hana", "đã bình luận: hay quá",
                Map.of("notificationId", "10", "type", "VIDEO_COMMENTED", "videoId", "7", "commentId", "9"));
    }

    @Test
    void approvedAndRejectedPushesAreSystemMessages() {
        NotificationResponse approved = base(NotificationType.VIDEO_APPROVED).videoTitle("Chào hỏi").build();
        NotificationResponse rejected = base(NotificationType.VIDEO_REJECTED).videoTitle("Chào hỏi")
                .detail("Nội dung vi phạm").build();

        notifier.onNotificationCreated(event(approved));
        notifier.onNotificationCreated(event(rejected));

        verify(fcmClient).send("token-a", "Video đã được duyệt", "Chào hỏi đã được đăng công khai",
                Map.of("notificationId", "10", "type", "VIDEO_APPROVED", "videoId", "7"));
        verify(fcmClient).send("token-a", "Video bị từ chối", "Chào hỏi: Nội dung vi phạm",
                Map.of("notificationId", "10", "type", "VIDEO_REJECTED", "videoId", "7"));
    }

    @Test
    void longCommentPreviewIsShortened() {
        assertThat(NotificationPushNotifier.body(commented("あ".repeat(500))))
                .isEqualTo("đã bình luận: " + "あ".repeat(120) + "…");
    }

    @Test
    void likesOnSameVideoArePushedOncePerInterval() {
        NotificationResponse like = base(NotificationType.VIDEO_LIKED).build();

        notifier.onNotificationCreated(event(like));
        notifier.onNotificationCreated(event(like));

        verify(fcmClient, times(1)).send(anyString(), anyString(), anyString(), any());
    }

    @Test
    void likeThrottleIsPerVideoAndExpires() {
        NotificationResponse like = base(NotificationType.VIDEO_LIKED).build();
        NotificationResponse otherVideoLike = base(NotificationType.VIDEO_LIKED).videoId(8L).build();
        long interval = NotificationPushNotifier.LIKE_PUSH_INTERVAL.toMillis();

        assertThat(notifier.isThrottledLike(RECIPIENT, like, 0)).isFalse();
        assertThat(notifier.isThrottledLike(RECIPIENT, like, interval - 1)).isTrue();
        assertThat(notifier.isThrottledLike(RECIPIENT, otherVideoLike, 1)).isFalse();
        assertThat(notifier.isThrottledLike(RECIPIENT, like, interval)).isFalse();
    }

    @Test
    void commentsAreNeverThrottled() {
        notifier.onNotificationCreated(event(commented("một")));
        notifier.onNotificationCreated(event(commented("hai")));

        verify(fcmClient, times(2)).send(anyString(), anyString(), anyString(), any());
    }

    @Test
    void invalidTokenIsRemoved() {
        when(fcmClient.send(anyString(), anyString(), anyString(), any())).thenReturn(FcmClient.Result.TOKEN_INVALID);

        notifier.onNotificationCreated(event(commented("hay quá")));

        verify(deviceTokenRepository).deleteByToken("token-a");
    }

    @Test
    void noTokensMeansNoPush() {
        when(deviceTokenRepository.findTokensByUserId(RECIPIENT)).thenReturn(List.of());

        notifier.onNotificationCreated(event(commented("hay quá")));

        verify(fcmClient, never()).send(anyString(), anyString(), anyString(), any());
    }

    private static NotificationCreatedEvent event(NotificationResponse notification) {
        return new NotificationCreatedEvent(notification, RECIPIENT);
    }

    private static NotificationResponse commented(String content) {
        return base(NotificationType.VIDEO_COMMENTED).commentId(9L).detail(content).build();
    }

    private static NotificationResponse.NotificationResponseBuilder base(NotificationType type) {
        return NotificationResponse.builder()
                .id(10L).type(type).category(type.getCategory()).actorId(2L).actorName("Hana").videoId(7L);
    }
}
