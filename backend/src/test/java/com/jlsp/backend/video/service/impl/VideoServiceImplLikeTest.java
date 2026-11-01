package com.jlsp.backend.video.service.impl;

import com.jlsp.backend.block.service.BlockService;
import com.jlsp.backend.common.security.ratelimit.RateLimiter;
import com.jlsp.backend.notification.entity.NotificationType;
import com.jlsp.backend.notification.service.NotificationService;
import com.jlsp.backend.report.repository.ReportRepository;
import com.jlsp.backend.topic.service.TopicService;
import com.jlsp.backend.user.entity.User;
import com.jlsp.backend.user.repository.FollowRepository;
import com.jlsp.backend.user.repository.UserRepository;
import com.jlsp.backend.video.entity.Video;
import com.jlsp.backend.video.entity.VideoLikeId;
import com.jlsp.backend.video.mapper.VideoMapper;
import com.jlsp.backend.video.repository.ShadowingPracticeRepository;
import com.jlsp.backend.video.repository.VideoCommentRepository;
import com.jlsp.backend.video.repository.VideoLikeRepository;
import com.jlsp.backend.video.repository.VideoRepository;
import com.jlsp.backend.video.repository.VideoSaveRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Thích video: người A thích video của người B thì B phải nhận thông báo. App gọi POST /likes (likeVideo);
 * toggleLike là endpoint cũ cho client cũ, cả hai đều phải báo.
 */
class VideoServiceImplLikeTest {

    private static final long VIDEO_ID = 10L;
    private static final long OWNER_B = 1L;
    private static final long LIKER_A = 2L;

    private VideoRepository videoRepository;
    private VideoLikeRepository videoLikeRepository;
    private NotificationService notificationService;
    private VideoServiceImpl service;

    @BeforeEach
    void setUp() {
        videoRepository = mock(VideoRepository.class);
        videoLikeRepository = mock(VideoLikeRepository.class);
        notificationService = mock(NotificationService.class);
        UserRepository userRepository = mock(UserRepository.class);
        service = new VideoServiceImpl(videoRepository, videoLikeRepository, mock(VideoSaveRepository.class),
                mock(VideoCommentRepository.class), mock(ShadowingPracticeRepository.class), userRepository,
                mock(FollowRepository.class), new VideoMapper(), mock(TopicService.class),
                mock(com.jlsp.backend.video.service.HashtagService.class), notificationService,
                mock(BlockService.class), mock(RateLimiter.class), mock(ReportRepository.class));

        Video video = Video.builder().id(VIDEO_ID).user(User.builder().id(OWNER_B).build()).build();
        when(videoRepository.findById(VIDEO_ID)).thenReturn(Optional.of(video));
        when(videoRepository.existsById(VIDEO_ID)).thenReturn(true);
        when(userRepository.findById(LIKER_A)).thenReturn(Optional.of(User.builder().id(LIKER_A).build()));
    }

    @Test
    void likeVideoNotifiesTheVideoOwner() {
        when(videoLikeRepository.existsById(new VideoLikeId(LIKER_A, VIDEO_ID))).thenReturn(false);

        service.likeVideo(VIDEO_ID, LIKER_A);

        verify(videoRepository).updateLikeCount(VIDEO_ID, 1);
        verify(notificationService).notify(OWNER_B, LIKER_A, NotificationType.LIKE, VIDEO_ID, null, null);
    }

    @Test
    void likingAnAlreadyLikedVideoDoesNotNotifyAgain() {
        when(videoLikeRepository.existsById(new VideoLikeId(LIKER_A, VIDEO_ID))).thenReturn(false, true);

        service.likeVideo(VIDEO_ID, LIKER_A);
        service.likeVideo(VIDEO_ID, LIKER_A);

        verify(notificationService, times(1)).notify(OWNER_B, LIKER_A, NotificationType.LIKE, VIDEO_ID, null, null);
    }

    @Test
    void unlikeDoesNotNotify() {
        when(videoLikeRepository.existsById(new VideoLikeId(LIKER_A, VIDEO_ID))).thenReturn(true);

        service.unlikeVideo(VIDEO_ID, LIKER_A);

        verify(notificationService, never()).notify(any(), any(), any(), any(), any(), any());
    }

    @Test
    void legacyToggleLikeStillNotifiesOnTheLikeSideOnly() {
        when(videoLikeRepository.existsById(new VideoLikeId(LIKER_A, VIDEO_ID))).thenReturn(false, true);

        assertThat(service.toggleLike(VIDEO_ID, LIKER_A)).isTrue();
        assertThat(service.toggleLike(VIDEO_ID, LIKER_A)).isFalse();

        verify(notificationService, times(1)).notify(OWNER_B, LIKER_A, NotificationType.LIKE, VIDEO_ID, null, null);
    }
}
