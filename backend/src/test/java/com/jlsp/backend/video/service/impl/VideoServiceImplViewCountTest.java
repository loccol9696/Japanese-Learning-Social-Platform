package com.jlsp.backend.video.service.impl;

import com.jlsp.backend.block.service.BlockService;
import com.jlsp.backend.common.exception.ResourceNotFoundException;
import com.jlsp.backend.common.security.ratelimit.RateLimiter;
import com.jlsp.backend.common.security.ratelimit.RateLimiter.Decision;
import com.jlsp.backend.notification.service.NotificationService;
import com.jlsp.backend.topic.service.TopicService;
import com.jlsp.backend.user.repository.FollowRepository;
import com.jlsp.backend.user.repository.UserRepository;
import com.jlsp.backend.video.mapper.VideoMapper;
import com.jlsp.backend.video.repository.ShadowingPracticeRepository;
import com.jlsp.backend.video.repository.VideoCommentRepository;
import com.jlsp.backend.video.repository.VideoLikeRepository;
import com.jlsp.backend.video.repository.VideoRepository;
import com.jlsp.backend.video.repository.VideoSaveRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.time.Duration;

import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/** Lượt xem: mỗi người xem chỉ được tính một lần cho mỗi video trong một khoảng thời gian. */
class VideoServiceImplViewCountTest {

    private static final long VIDEO_ID = 10L;

    private VideoRepository videoRepository;
    private RateLimiter rateLimiter;
    private VideoServiceImpl service;

    @BeforeEach
    void setUp() {
        videoRepository = mock(VideoRepository.class);
        rateLimiter = mock(RateLimiter.class);
        service = new VideoServiceImpl(videoRepository, mock(VideoLikeRepository.class),
                mock(VideoSaveRepository.class), mock(VideoCommentRepository.class),
                mock(ShadowingPracticeRepository.class), mock(UserRepository.class), mock(FollowRepository.class),
                new VideoMapper(), mock(TopicService.class),
                mock(com.jlsp.backend.video.service.HashtagService.class), mock(NotificationService.class),
                mock(BlockService.class), rateLimiter,
                mock(org.springframework.context.ApplicationEventPublisher.class));
        when(videoRepository.existsById(VIDEO_ID)).thenReturn(true);
    }

    @Test
    void firstViewInTheWindowIsCounted() {
        when(rateLimiter.tryAcquire(anyString(), anyInt(), any())).thenReturn(Decision.ALLOWED);

        service.incrementViewCount(VIDEO_ID, "u7");

        verify(rateLimiter).tryAcquire("view:10:u7", 1, VideoServiceImpl.VIEW_DEDUP_WINDOW);
        verify(videoRepository).incrementViewCount(VIDEO_ID);
    }

    @Test
    void repeatedViewByTheSameViewerIsIgnored() {
        when(rateLimiter.tryAcquire(eq("view:10:ip203.0.113.9"), anyInt(), any()))
                .thenReturn(new Decision(false, 900));

        service.incrementViewCount(VIDEO_ID, "ip203.0.113.9");

        verify(videoRepository, never()).incrementViewCount(VIDEO_ID);
    }

    @Test
    void differentViewersAreCountedIndependently() {
        when(rateLimiter.tryAcquire(anyString(), anyInt(), any())).thenReturn(Decision.ALLOWED);

        service.incrementViewCount(VIDEO_ID, "u7");
        service.incrementViewCount(VIDEO_ID, "u8");

        verify(videoRepository, org.mockito.Mockito.times(2)).incrementViewCount(VIDEO_ID);
    }

    @Test
    void windowIsLongEnoughToStopQuickReplays() {
        org.assertj.core.api.Assertions.assertThat(VideoServiceImpl.VIEW_DEDUP_WINDOW)
                .isGreaterThanOrEqualTo(Duration.ofMinutes(10));
    }

    @Test
    void unknownVideoIsNotFoundAndDoesNotTouchRedis() {
        when(videoRepository.existsById(99L)).thenReturn(false);

        assertThatThrownBy(() -> service.incrementViewCount(99L, "u7"))
                .isInstanceOf(ResourceNotFoundException.class);

        verify(rateLimiter, never()).tryAcquire(anyString(), anyInt(), any());
        verify(videoRepository, never()).incrementViewCount(99L);
    }

    @Test
    void viewWithoutAViewerKeyIsAlwaysCounted() {
        service.incrementViewCount(VIDEO_ID, null);

        verify(rateLimiter, never()).tryAcquire(anyString(), anyInt(), any());
        verify(videoRepository).incrementViewCount(VIDEO_ID);
    }
}
