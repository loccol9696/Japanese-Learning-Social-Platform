package com.jlsp.backend.video.service.impl;

import com.jlsp.backend.notification.entity.NotificationType;
import com.jlsp.backend.notification.event.NotificationRequestedEvent;
import com.jlsp.backend.user.entity.User;
import com.jlsp.backend.user.repository.FollowRepository;
import com.jlsp.backend.user.repository.UserRepository;
import com.jlsp.backend.video.entity.Video;
import com.jlsp.backend.video.entity.VideoLikeId;
import com.jlsp.backend.video.entity.VideoModStatus;
import com.jlsp.backend.video.entity.VideoStatus;
import com.jlsp.backend.video.mapper.VideoMapper;
import com.jlsp.backend.video.repository.ShadowingPracticeRepository;
import com.jlsp.backend.video.repository.VideoCommentRepository;
import com.jlsp.backend.video.repository.VideoLikeRepository;
import com.jlsp.backend.video.repository.VideoRepository;
import com.jlsp.backend.video.repository.VideoSaveRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.context.ApplicationEventPublisher;

import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.atLeast;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/** Các điểm VideoServiceImpl phát yêu cầu tạo thông báo: thích, duyệt, từ chối. */
class VideoServiceImplNotificationTest {

    private static final long OWNER = 1L;
    private static final long LIKER = 2L;
    private static final long MODERATOR = 3L;
    private static final long VIDEO = 7L;

    private VideoRepository videoRepository;
    private VideoLikeRepository videoLikeRepository;
    private UserRepository userRepository;
    private ApplicationEventPublisher eventPublisher;
    private VideoServiceImpl service;
    private Video video;

    @BeforeEach
    void setUp() {
        videoRepository = mock(VideoRepository.class);
        videoLikeRepository = mock(VideoLikeRepository.class);
        userRepository = mock(UserRepository.class);
        eventPublisher = mock(ApplicationEventPublisher.class);
        service = new VideoServiceImpl(videoRepository, videoLikeRepository, mock(VideoSaveRepository.class),
                mock(VideoCommentRepository.class), mock(ShadowingPracticeRepository.class), userRepository,
                mock(FollowRepository.class), mock(VideoMapper.class), eventPublisher);

        User owner = User.builder().id(OWNER).build();
        video = Video.builder().id(VIDEO).user(owner).status(VideoStatus.PUBLIC)
                .modStatus(VideoModStatus.PENDING).build();
        when(videoRepository.findById(VIDEO)).thenReturn(Optional.of(video));
        when(videoRepository.save(any(Video.class))).thenAnswer(call -> call.getArgument(0));
        when(userRepository.findById(LIKER)).thenReturn(Optional.of(User.builder().id(LIKER).build()));
    }

    @Test
    void likingNotifiesVideoOwner() {
        service.likeVideo(VIDEO, LIKER);

        assertThat(events()).singleElement().satisfies(event -> {
            assertThat(event.type()).isEqualTo(NotificationType.VIDEO_LIKED);
            assertThat(event.recipientId()).isEqualTo(OWNER);
            assertThat(event.actorId()).isEqualTo(LIKER);
            assertThat(event.dedupeKey()).isEqualTo("like:2:7");
        });
    }

    @Test
    void togglingLikeOnNotifiesButTogglingOffDoesNot() {
        when(videoLikeRepository.existsById(new VideoLikeId(LIKER, VIDEO))).thenReturn(false, true);

        service.toggleLike(VIDEO, LIKER);
        service.toggleLike(VIDEO, LIKER);

        assertThat(events()).singleElement()
                .satisfies(event -> assertThat(event.type()).isEqualTo(NotificationType.VIDEO_LIKED));
    }

    @Test
    void likingAgainWhenAlreadyLikedDoesNotNotify() {
        when(videoLikeRepository.existsById(new VideoLikeId(LIKER, VIDEO))).thenReturn(true);

        service.likeVideo(VIDEO, LIKER);

        assertThat(events()).isEmpty();
    }

    @Test
    void approvingNotifiesOwnerWithoutRevealingModerator() {
        service.approveVideo(VIDEO, MODERATOR);

        assertThat(events()).singleElement().satisfies(event -> {
            assertThat(event.type()).isEqualTo(NotificationType.VIDEO_APPROVED);
            assertThat(event.recipientId()).isEqualTo(OWNER);
            assertThat(event.actorId()).isNull();
        });
    }

    @Test
    void approvingAnAlreadyApprovedVideoDoesNotNotifyAgain() {
        video.setModStatus(VideoModStatus.APPROVED);

        service.approveVideo(VIDEO, MODERATOR);

        assertThat(events()).isEmpty();
    }

    @Test
    void rejectingNotifiesOwnerWithReason() {
        service.rejectVideo(VIDEO, MODERATOR, "Nội dung vi phạm");

        assertThat(events()).singleElement().satisfies(event -> {
            assertThat(event.type()).isEqualTo(NotificationType.VIDEO_REJECTED);
            assertThat(event.recipientId()).isEqualTo(OWNER);
            assertThat(event.detail()).isEqualTo("Nội dung vi phạm");
        });
    }

    @Test
    void rejectingWithoutReasonFallsBackToDefaultReason() {
        service.rejectVideo(VIDEO, MODERATOR, " ");

        assertThat(events()).singleElement().satisfies(event ->
                assertThat(event.detail()).isEqualTo("Vi phạm tiêu chuẩn cộng đồng hoặc chất lượng nội dung"));
    }

    @Test
    void rejectingAnAlreadyRejectedVideoDoesNotNotifyAgain() {
        video.setModStatus(VideoModStatus.REJECTED);

        service.rejectVideo(VIDEO, MODERATOR, "Nội dung vi phạm");

        assertThat(events()).isEmpty();
    }

    private List<NotificationRequestedEvent> events() {
        ArgumentCaptor<Object> published = ArgumentCaptor.forClass(Object.class);
        verify(eventPublisher, atLeast(0)).publishEvent(published.capture());
        return published.getAllValues().stream()
                .filter(NotificationRequestedEvent.class::isInstance)
                .map(NotificationRequestedEvent.class::cast)
                .toList();
    }
}
