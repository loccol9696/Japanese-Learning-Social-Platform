package com.jlsp.backend.notification.service.impl;

import com.jlsp.backend.chat.repository.UserBlockRepository;
import com.jlsp.backend.common.response.PageResponse;
import com.jlsp.backend.notification.dto.response.NotificationResponse;
import com.jlsp.backend.notification.entity.Notification;
import com.jlsp.backend.notification.entity.NotificationCategory;
import com.jlsp.backend.notification.entity.NotificationType;
import com.jlsp.backend.notification.event.NotificationCreatedEvent;
import com.jlsp.backend.notification.event.NotificationRequestedEvent;
import com.jlsp.backend.notification.repository.NotificationRepository;
import com.jlsp.backend.user.entity.User;
import com.jlsp.backend.user.repository.UserRepository;
import com.jlsp.backend.video.entity.Video;
import com.jlsp.backend.video.repository.VideoRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;

import java.time.LocalDateTime;
import java.util.Collection;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class NotificationServiceImplTest {

    private static final long OWNER = 1L;
    private static final long ACTOR = 2L;
    private static final long VIDEO = 7L;

    private NotificationRepository notificationRepository;
    private UserBlockRepository userBlockRepository;
    private UserRepository userRepository;
    private VideoRepository videoRepository;
    private ApplicationEventPublisher eventPublisher;
    private NotificationServiceImpl service;

    @BeforeEach
    void setUp() {
        notificationRepository = mock(NotificationRepository.class);
        userBlockRepository = mock(UserBlockRepository.class);
        userRepository = mock(UserRepository.class);
        videoRepository = mock(VideoRepository.class);
        eventPublisher = mock(ApplicationEventPublisher.class);
        service = new NotificationServiceImpl(notificationRepository, userBlockRepository, userRepository,
                videoRepository, eventPublisher);

        when(notificationRepository.save(any(Notification.class))).thenAnswer(invocation -> {
            Notification n = invocation.getArgument(0);
            n.setId(100L);
            n.setCreatedAt(LocalDateTime.of(2026, 10, 31, 9, 0));
            return n;
        });
        when(userRepository.findAllById(any())).thenReturn(
                List.of(User.builder().id(ACTOR).username("hana").displayName("Hana").avatarUrl("a.png").build()));
        when(videoRepository.findAllById(any())).thenReturn(
                List.of(Video.builder().id(VIDEO).title("Chào hỏi").thumbnailUrl("t.png").build()));
    }

    @Test
    void savesAndPublishesLikeNotification() {
        service.record(NotificationRequestedEvent.liked(OWNER, ACTOR, VIDEO));

        ArgumentCaptor<Notification> saved = ArgumentCaptor.forClass(Notification.class);
        verify(notificationRepository).save(saved.capture());
        assertThat(saved.getValue().getRecipientId()).isEqualTo(OWNER);
        assertThat(saved.getValue().getActorId()).isEqualTo(ACTOR);
        assertThat(saved.getValue().getType()).isEqualTo(NotificationType.VIDEO_LIKED);
        assertThat(saved.getValue().getDedupeKey()).isEqualTo("like:2:7");

        ArgumentCaptor<NotificationCreatedEvent> published = ArgumentCaptor.forClass(NotificationCreatedEvent.class);
        verify(eventPublisher).publishEvent(published.capture());
        NotificationResponse response = published.getValue().notification();
        assertThat(published.getValue().recipientId()).isEqualTo(OWNER);
        assertThat(response.getActorName()).isEqualTo("Hana");
        assertThat(response.getVideoTitle()).isEqualTo("Chào hỏi");
        assertThat(response.isVideoAvailable()).isTrue();
        assertThat(response.getCategory()).isEqualTo(NotificationCategory.INTERACTION);
        assertThat(response.isRead()).isFalse();
    }

    @Test
    void ignoresInteractionWithOwnVideo() {
        service.record(NotificationRequestedEvent.liked(OWNER, OWNER, VIDEO));

        verify(notificationRepository, never()).save(any());
        verify(eventPublisher, never()).publishEvent(any(Object.class));
    }

    @Test
    void ignoresInteractionBetweenBlockedUsers() {
        when(userBlockRepository.existsBetween(OWNER, ACTOR)).thenReturn(true);

        service.record(NotificationRequestedEvent.commented(OWNER, ACTOR, VIDEO, 9L, "hay quá"));

        verify(notificationRepository, never()).save(any());
    }

    @Test
    void ignoresRepeatedLikeFromSamePerson() {
        when(notificationRepository.existsByRecipientIdAndDedupeKey(OWNER, "like:2:7")).thenReturn(true);

        service.record(NotificationRequestedEvent.liked(OWNER, ACTOR, VIDEO));

        verify(notificationRepository, never()).save(any());
    }

    @Test
    void everyCommentIsNotifiedEvenFromSamePerson() {
        service.record(NotificationRequestedEvent.commented(OWNER, ACTOR, VIDEO, 9L, "một"));
        service.record(NotificationRequestedEvent.commented(OWNER, ACTOR, VIDEO, 10L, "hai"));

        verify(notificationRepository, never()).existsByRecipientIdAndDedupeKey(any(), anyString());
        verify(notificationRepository, org.mockito.Mockito.times(2)).save(any());
    }

    @Test
    void moderationNotificationHasNoActorAndKeepsReason() {
        service.record(NotificationRequestedEvent.rejected(OWNER, VIDEO, "Nội dung vi phạm"));

        ArgumentCaptor<Notification> saved = ArgumentCaptor.forClass(Notification.class);
        verify(notificationRepository).save(saved.capture());
        assertThat(saved.getValue().getActorId()).isNull();
        assertThat(saved.getValue().getDetail()).isEqualTo("Nội dung vi phạm");
        verify(userBlockRepository, never()).existsBetween(any(), any());
    }

    @Test
    void longCommentIsShortened() {
        service.record(NotificationRequestedEvent.commented(OWNER, ACTOR, VIDEO, 9L, "あ".repeat(500)));

        ArgumentCaptor<Notification> saved = ArgumentCaptor.forClass(Notification.class);
        verify(notificationRepository).save(saved.capture());
        assertThat(saved.getValue().getDetail()).isEqualTo("あ".repeat(200) + "…");
    }

    @Test
    void deletedVideoIsReportedAsUnavailable() {
        when(videoRepository.findAllById(any())).thenReturn(List.of());

        service.record(NotificationRequestedEvent.liked(OWNER, ACTOR, VIDEO));

        ArgumentCaptor<NotificationCreatedEvent> published = ArgumentCaptor.forClass(NotificationCreatedEvent.class);
        verify(eventPublisher).publishEvent(published.capture());
        assertThat(published.getValue().notification().isVideoAvailable()).isFalse();
        assertThat(published.getValue().notification().getVideoTitle()).isNull();
    }

    @Test
    @SuppressWarnings("unchecked")
    void listFiltersByCategoryAndCapsPageSize() {
        Notification approved = Notification.builder().id(5L).recipientId(OWNER).type(NotificationType.VIDEO_APPROVED)
                .videoId(VIDEO).createdAt(LocalDateTime.now()).readAt(LocalDateTime.now()).build();
        Page<Notification> page = new PageImpl<>(List.of(approved), PageRequest.of(0, 50), 1);
        when(notificationRepository.findByRecipientIdAndTypeInOrderByCreatedAtDescIdDesc(
                eq(OWNER), any(Collection.class), any(Pageable.class))).thenReturn(page);

        PageResponse<NotificationResponse> result =
                service.list(OWNER, NotificationCategory.SYSTEM, PageRequest.of(0, 500));

        ArgumentCaptor<Collection<NotificationType>> types = ArgumentCaptor.forClass(Collection.class);
        ArgumentCaptor<Pageable> pageable = ArgumentCaptor.forClass(Pageable.class);
        verify(notificationRepository).findByRecipientIdAndTypeInOrderByCreatedAtDescIdDesc(
                eq(OWNER), types.capture(), pageable.capture());
        assertThat(types.getValue()).containsExactlyInAnyOrder(
                NotificationType.VIDEO_APPROVED, NotificationType.VIDEO_REJECTED);
        assertThat(pageable.getValue().getPageSize()).isEqualTo(50);
        assertThat(result.getContent()).hasSize(1);
        assertThat(result.getContent().get(0).isRead()).isTrue();
        assertThat(result.getContent().get(0).getActorName()).isNull();
    }

    @Test
    void deleteByCommentsSkipsEmptyList() {
        service.deleteByComments(List.of());

        verify(notificationRepository, never()).deleteByCommentIds(any());
    }
}
