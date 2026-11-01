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
import com.jlsp.backend.video.entity.VideoSaveId;
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
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/** Lưu video: chủ video được báo khi có người lưu mới, không báo khi bỏ lưu hoặc lưu lại video đã lưu. */
class VideoServiceImplSaveTest {

    private static final long VIDEO_ID = 10L;
    private static final long OWNER = 1L;
    private static final long SAVER = 2L;

    private VideoRepository videoRepository;
    private VideoSaveRepository videoSaveRepository;
    private NotificationService notificationService;
    private VideoServiceImpl service;

    @BeforeEach
    void setUp() {
        videoRepository = mock(VideoRepository.class);
        videoSaveRepository = mock(VideoSaveRepository.class);
        notificationService = mock(NotificationService.class);
        UserRepository userRepository = mock(UserRepository.class);
        service = new VideoServiceImpl(videoRepository, mock(VideoLikeRepository.class), videoSaveRepository,
                mock(VideoCommentRepository.class), mock(ShadowingPracticeRepository.class), userRepository,
                mock(FollowRepository.class), new VideoMapper(), mock(TopicService.class),
                mock(com.jlsp.backend.video.service.HashtagService.class), notificationService,
                mock(BlockService.class), mock(RateLimiter.class), mock(ReportRepository.class));

        Video video = Video.builder().id(VIDEO_ID).user(User.builder().id(OWNER).build()).build();
        when(videoRepository.findById(VIDEO_ID)).thenReturn(Optional.of(video));
        when(userRepository.findById(SAVER)).thenReturn(Optional.of(User.builder().id(SAVER).build()));
    }

    @Test
    void togglingToSavedNotifiesTheOwner() {
        when(videoSaveRepository.existsById(new VideoSaveId(SAVER, VIDEO_ID))).thenReturn(false);

        assertThat(service.toggleSave(VIDEO_ID, SAVER)).isTrue();

        verify(videoRepository).updateSaveCount(VIDEO_ID, 1);
        verify(notificationService).notify(OWNER, SAVER, NotificationType.VIDEO_SAVED, VIDEO_ID, null, null);
    }

    @Test
    void togglingToUnsavedDoesNotNotify() {
        when(videoSaveRepository.existsById(new VideoSaveId(SAVER, VIDEO_ID))).thenReturn(true);

        assertThat(service.toggleSave(VIDEO_ID, SAVER)).isFalse();

        verify(notificationService, never()).notify(any(), any(), any(), any(), any(), any());
    }

    @Test
    void saveVideoNotifiesOnlyWhenItWasNotAlreadySaved() {
        when(videoSaveRepository.existsById(new VideoSaveId(SAVER, VIDEO_ID))).thenReturn(false, true);

        service.saveVideo(VIDEO_ID, SAVER);
        service.saveVideo(VIDEO_ID, SAVER);

        verify(videoRepository).updateSaveCount(VIDEO_ID, 1);
        verify(notificationService, org.mockito.Mockito.times(1))
                .notify(OWNER, SAVER, NotificationType.VIDEO_SAVED, VIDEO_ID, null, null);
    }
}
