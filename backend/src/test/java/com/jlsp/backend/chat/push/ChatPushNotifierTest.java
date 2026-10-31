package com.jlsp.backend.chat.push;

import com.jlsp.backend.chat.dto.response.MessageResponse;
import com.jlsp.backend.chat.entity.MessageType;
import com.jlsp.backend.chat.event.MessageCreatedEvent;
import com.jlsp.backend.chat.repository.DeviceTokenRepository;
import com.jlsp.backend.user.entity.User;
import com.jlsp.backend.user.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Map;
import java.util.Optional;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

class ChatPushNotifierTest {

    private static final long SENDER = 1L;
    private static final long RECIPIENT = 2L;

    private FcmClient fcmClient;
    private DeviceTokenRepository deviceTokenRepository;
    private ChatPushNotifier notifier;

    @BeforeEach
    void setUp() {
        fcmClient = mock(FcmClient.class);
        deviceTokenRepository = mock(DeviceTokenRepository.class);
        UserRepository userRepository = mock(UserRepository.class);
        notifier = new ChatPushNotifier(fcmClient, deviceTokenRepository, userRepository);

        when(fcmClient.isEnabled()).thenReturn(true);
        when(userRepository.findById(SENDER))
                .thenReturn(Optional.of(User.builder().id(SENDER).displayName("Hana").build()));
        when(deviceTokenRepository.findTokensByUserId(RECIPIENT)).thenReturn(List.of("token-a"));
    }

    @Test
    void doesNothingWhenFcmIsNotConfigured() {
        when(fcmClient.isEnabled()).thenReturn(false);

        notifier.onMessageCreated(event(textMessage("こんにちは")));

        verifyNoInteractions(deviceTokenRepository);
        verify(fcmClient, never()).send(anyString(), anyString(), anyString(), any());
    }

    @Test
    void sendsSenderNameAndPreviewWithConversationId() {
        when(fcmClient.send(anyString(), anyString(), anyString(), any())).thenReturn(FcmClient.Result.SENT);

        notifier.onMessageCreated(event(textMessage("こんにちは")));

        verify(fcmClient).send("token-a", "Hana", "こんにちは",
                Map.of("conversationId", "10", "messageId", "5"));
        verify(deviceTokenRepository, never()).deleteByToken(anyString());
    }

    @Test
    void imagePreviewDoesNotNeedText() {
        when(fcmClient.send(anyString(), anyString(), anyString(), any())).thenReturn(FcmClient.Result.SENT);
        MessageResponse image = MessageResponse.builder()
                .id(5L).conversationId(10L).senderId(SENDER).type(MessageType.IMAGE).build();

        notifier.onMessageCreated(event(image));

        verify(fcmClient).send(eq("token-a"), eq("Hana"), eq("📷 Đã gửi một ảnh"), any());
    }

    @Test
    void longTextIsShortened() {
        when(fcmClient.send(anyString(), anyString(), anyString(), any())).thenReturn(FcmClient.Result.SENT);

        notifier.onMessageCreated(event(textMessage("あ".repeat(500))));

        verify(fcmClient).send(eq("token-a"), eq("Hana"), eq("あ".repeat(120) + "…"), any());
    }

    @Test
    void invalidTokenIsRemoved() {
        when(fcmClient.send(anyString(), anyString(), anyString(), any())).thenReturn(FcmClient.Result.TOKEN_INVALID);

        notifier.onMessageCreated(event(textMessage("こんにちは")));

        verify(deviceTokenRepository).deleteByToken("token-a");
    }

    private static MessageCreatedEvent event(MessageResponse message) {
        return new MessageCreatedEvent(message, SENDER, RECIPIENT);
    }

    private static MessageResponse textMessage(String content) {
        return MessageResponse.builder()
                .id(5L).conversationId(10L).senderId(SENDER).type(MessageType.TEXT).content(content).build();
    }
}
