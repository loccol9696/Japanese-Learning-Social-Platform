package com.jlsp.backend.notification.service.impl;

import com.jlsp.backend.common.exception.ResourceNotFoundException;
import com.jlsp.backend.common.response.PageResponse;
import com.jlsp.backend.notification.dto.NotificationResponse;
import com.jlsp.backend.notification.entity.Notification;
import com.jlsp.backend.notification.entity.NotificationType;
import com.jlsp.backend.notification.event.NotificationCreatedEvent;
import com.jlsp.backend.notification.repository.NotificationRepository;
import com.jlsp.backend.user.entity.User;
import com.jlsp.backend.user.repository.UserRepository;
import com.jlsp.backend.video.entity.Video;
import com.jlsp.backend.video.repository.VideoRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;

import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyIterable;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class NotificationServiceImplTest {

    private static final long RECIPIENT = 1L;
    private static final long ACTOR = 2L;
    private static final long VIDEO_ID = 50L;
    private static final Pageable PAGE = PageRequest.of(0, 20);

    private NotificationRepository repository;
    private UserRepository userRepository;
    private VideoRepository videoRepository;
    private ApplicationEventPublisher publisher;
    private NotificationServiceImpl service;

    private User actor;
    private User recipient;

    @BeforeEach
    void setUp() {
        repository = mock(NotificationRepository.class);
        userRepository = mock(UserRepository.class);
        videoRepository = mock(VideoRepository.class);
        publisher = mock(ApplicationEventPublisher.class);
        service = new NotificationServiceImpl(repository, userRepository, videoRepository, publisher);

        actor = User.builder().id(ACTOR).username("actor").displayName("Actor").build();
        recipient = User.builder().id(RECIPIENT).username("recipient").build();
        when(userRepository.findById(ACTOR)).thenReturn(Optional.of(actor));
        when(userRepository.getReferenceById(RECIPIENT)).thenReturn(recipient);
        when(videoRepository.findById(VIDEO_ID))
                .thenReturn(Optional.of(Video.builder().id(VIDEO_ID).title("Bài học").build()));
        when(repository.save(any(Notification.class))).thenAnswer(inv -> {
            Notification n = inv.getArgument(0);
            n.setId(10L);
            return n;
        });
        when(repository.countByRecipientIdAndIsReadFalse(RECIPIENT)).thenReturn(3L);
    }

    @Test
    void savesAndPublishesAnEventWithTheUnreadCount() {
        service.notify(RECIPIENT, ACTOR, NotificationType.COMMENT, VIDEO_ID, 7L, "  hay quá  ");

        ArgumentCaptor<NotificationCreatedEvent> event = ArgumentCaptor.forClass(NotificationCreatedEvent.class);
        verify(publisher).publishEvent(event.capture());
        assertThat(event.getValue().recipientId()).isEqualTo(RECIPIENT);
        assertThat(event.getValue().unreadCount()).isEqualTo(3L);
        NotificationResponse payload = event.getValue().notification();
        assertThat(payload.getMessage()).isEqualTo("hay quá");
        assertThat(payload.getActorUsername()).isEqualTo("actor");
        assertThat(payload.getVideoTitle()).isEqualTo("Bài học");
        assertThat(payload.getIsRead()).isFalse();
    }

    @Test
    void neverNotifiesSomeoneAboutTheirOwnAction() {
        service.notify(RECIPIENT, RECIPIENT, NotificationType.LIKE, VIDEO_ID, null, null);

        verify(repository, never()).save(any());
        verify(publisher, never()).publishEvent(any(Object.class));
    }

    @Test
    void likeIsOnlyNotifiedOncePerActorAndVideo() {
        when(repository.existsByRecipientIdAndActorIdAndTypeAndVideoId(
                RECIPIENT, ACTOR, NotificationType.LIKE, VIDEO_ID)).thenReturn(true);

        service.notify(RECIPIENT, ACTOR, NotificationType.LIKE, VIDEO_ID, null, null);

        verify(repository, never()).save(any());
    }

    @Test
    void followIsOnlyNotifiedOncePerActor() {
        when(repository.existsByRecipientIdAndActorIdAndType(RECIPIENT, ACTOR, NotificationType.FOLLOW))
                .thenReturn(true);

        service.notify(RECIPIENT, ACTOR, NotificationType.FOLLOW, null, null, null);

        verify(repository, never()).save(any());
    }

    @Test
    void commentsAreNotDeduplicated() {
        service.notify(RECIPIENT, ACTOR, NotificationType.COMMENT, VIDEO_ID, 1L, "một");
        service.notify(RECIPIENT, ACTOR, NotificationType.COMMENT, VIDEO_ID, 2L, "hai");

        verify(repository, org.mockito.Mockito.times(2)).save(any());
    }

    @Test
    void systemNotificationsHaveNoActor() {
        service.notify(RECIPIENT, null, NotificationType.VIDEO_REJECTED, VIDEO_ID, null, "Vi phạm");

        ArgumentCaptor<NotificationCreatedEvent> event = ArgumentCaptor.forClass(NotificationCreatedEvent.class);
        verify(publisher).publishEvent(event.capture());
        assertThat(event.getValue().notification().getActorId()).isNull();
        assertThat(event.getValue().notification().getMessage()).isEqualTo("Vi phạm");
    }

    @Test
    void aFailureWhileNotifyingDoesNotBreakTheCaller() {
        when(repository.save(any(Notification.class))).thenThrow(new IllegalStateException("db down"));

        assertThatCode(() -> service.notify(RECIPIENT, ACTOR, NotificationType.LIKE, VIDEO_ID, null, null))
                .doesNotThrowAnyException();
        verify(publisher, never()).publishEvent(any(Object.class));
    }

    @Test
    void listAttachesVideoTitlesWithOneBatchedLookup() {
        Notification withVideo = Notification.builder().id(1L).recipient(recipient).actor(actor)
                .type(NotificationType.LIKE).videoId(VIDEO_ID).build();
        Notification withoutVideo = Notification.builder().id(2L).recipient(recipient)
                .type(NotificationType.FOLLOW).actor(actor).build();
        when(repository.findByRecipientId(RECIPIENT, PAGE))
                .thenReturn(new PageImpl<>(List.of(withVideo, withoutVideo), PAGE, 2));
        when(videoRepository.findAllById(anyIterable()))
                .thenReturn(List.of(Video.builder().id(VIDEO_ID).title("Bài học").build()));

        PageResponse<NotificationResponse> result = service.list(RECIPIENT, false, PAGE);

        assertThat(result.getContent()).extracting(NotificationResponse::getVideoTitle)
                .containsExactly("Bài học", null);
        verify(videoRepository).findAllById(anyIterable());
    }

    @Test
    void unreadOnlyUsesTheUnreadQuery() {
        when(repository.findByRecipientIdAndIsReadFalse(RECIPIENT, PAGE)).thenReturn(new PageImpl<>(List.of()));

        service.list(RECIPIENT, true, PAGE);

        verify(repository).findByRecipientIdAndIsReadFalse(RECIPIENT, PAGE);
        verify(repository, never()).findByRecipientId(any(), any());
    }

    @Test
    void cannotMarkSomeoneElsesNotificationAsRead() {
        when(repository.findByIdAndRecipientId(99L, RECIPIENT)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.markRead(RECIPIENT, 99L)).isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void markReadFlipsTheFlagOnlyOnce() {
        Notification unread = Notification.builder().id(5L).recipient(recipient).type(NotificationType.FOLLOW).build();
        when(repository.findByIdAndRecipientId(5L, RECIPIENT)).thenReturn(Optional.of(unread));

        service.markRead(RECIPIENT, 5L);
        service.markRead(RECIPIENT, 5L);

        assertThat(unread.getIsRead()).isTrue();
        verify(repository, org.mockito.Mockito.times(1)).save(unread);
    }
}
