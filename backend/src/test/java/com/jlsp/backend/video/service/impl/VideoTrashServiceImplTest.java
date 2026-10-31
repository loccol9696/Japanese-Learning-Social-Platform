package com.jlsp.backend.video.service.impl;

import com.jlsp.backend.common.exception.AppException;
import com.jlsp.backend.common.exception.ResourceNotFoundException;
import com.jlsp.backend.user.entity.User;
import com.jlsp.backend.user.entity.UserRole;
import com.jlsp.backend.user.repository.UserRepository;
import com.jlsp.backend.video.dto.response.VideoResponse;
import com.jlsp.backend.video.entity.Video;
import com.jlsp.backend.video.event.VideoPurgedEvent;
import com.jlsp.backend.video.mapper.VideoMapper;
import com.jlsp.backend.video.repository.VideoCommentRepository;
import com.jlsp.backend.video.repository.VideoRepository;
import com.jlsp.backend.video.repository.VideoTrashStore;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.test.util.ReflectionTestUtils;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class VideoTrashServiceImplTest {

    private static final long OWNER = 1L;
    private static final long STRANGER = 2L;
    private static final long ADMIN = 3L;
    private static final long VIDEO = 7L;
    private static final int RETENTION_DAYS = 30;
    private static final String VIDEO_URL = "https://res.cloudinary.com/demo/video/upload/v1/a.mp4";
    private static final String THUMBNAIL_URL = "https://res.cloudinary.com/demo/image/upload/v1/a.jpg";

    private VideoRepository videoRepository;
    private VideoCommentRepository commentRepository;
    private VideoTrashStore trashStore;
    private VideoMapper videoMapper;
    private ApplicationEventPublisher eventPublisher;
    private VideoTrashServiceImpl service;

    @BeforeEach
    void setUp() {
        videoRepository = mock(VideoRepository.class);
        commentRepository = mock(VideoCommentRepository.class);
        trashStore = mock(VideoTrashStore.class);
        videoMapper = mock(VideoMapper.class);
        eventPublisher = mock(ApplicationEventPublisher.class);
        UserRepository userRepository = mock(UserRepository.class);
        service = new VideoTrashServiceImpl(videoRepository, commentRepository, trashStore, userRepository,
                videoMapper, eventPublisher);
        ReflectionTestUtils.setField(service, "retentionDays", RETENTION_DAYS);

        when(userRepository.findById(OWNER)).thenReturn(Optional.of(user(OWNER, UserRole.USER)));
        when(userRepository.findById(STRANGER)).thenReturn(Optional.of(user(STRANGER, UserRole.USER)));
        when(userRepository.findById(ADMIN)).thenReturn(Optional.of(user(ADMIN, UserRole.ADMIN)));
    }

    @Test
    void movingToTrashSoftDeletesVideoAndDependents() {
        when(videoRepository.findById(VIDEO)).thenReturn(Optional.of(video(null)));
        LocalDateTime before = LocalDateTime.now();

        service.moveToTrash(VIDEO, OWNER);

        ArgumentCaptor<LocalDateTime> deletedAt = ArgumentCaptor.forClass(LocalDateTime.class);
        verify(trashStore).softDelete(eq(VIDEO), deletedAt.capture());
        assertThat(deletedAt.getValue()).isAfterOrEqualTo(before);
    }

    @Test
    void strangerCannotMoveVideoToTrash() {
        when(videoRepository.findById(VIDEO)).thenReturn(Optional.of(video(null)));

        assertThatThrownBy(() -> service.moveToTrash(VIDEO, STRANGER)).isInstanceOf(AppException.class);

        verify(trashStore, never()).softDelete(any(), any());
    }

    @Test
    void adminCanMoveAnyVideoToTrash() {
        when(videoRepository.findById(VIDEO)).thenReturn(Optional.of(video(null)));

        service.moveToTrash(VIDEO, ADMIN);

        verify(trashStore).softDelete(eq(VIDEO), any());
    }

    @Test
    void trashListShowsWhenEachVideoWillBePurgedAndIgnoresClientSort() {
        LocalDateTime deletedAt = LocalDateTime.now().minusDays(10);
        Video video = video(deletedAt);
        Pageable requested = PageRequest.of(1, 5, org.springframework.data.domain.Sort.by("title"));
        when(videoRepository.findTrashByUserId(eq(OWNER), any(), eq(PageRequest.of(1, 5))))
                .thenReturn(new PageImpl<>(List.of(video), PageRequest.of(1, 5), 6));
        when(videoMapper.toVideoResponse(video, false, false, 0L)).thenReturn(new VideoResponse());

        VideoResponse response = service.listTrash(OWNER, requested).getContent().get(0);

        assertThat(response.getDeletedAt()).isEqualTo(deletedAt);
        assertThat(response.getPurgeAt()).isEqualTo(deletedAt.plusDays(RETENTION_DAYS));
    }

    @Test
    void restoreWithinRetentionBringsVideoBack() {
        when(videoRepository.findDeletedById(VIDEO))
                .thenReturn(Optional.of(video(LocalDateTime.now().minusDays(RETENTION_DAYS - 1))));

        service.restore(VIDEO, OWNER);

        verify(trashStore).restore(VIDEO);
    }

    @Test
    void videoPastRetentionCannotBeRestoredEvenIfJobHasNotRun() {
        when(videoRepository.findDeletedById(VIDEO))
                .thenReturn(Optional.of(video(LocalDateTime.now().minusDays(RETENTION_DAYS + 1))));

        assertThatThrownBy(() -> service.restore(VIDEO, OWNER)).isInstanceOf(ResourceNotFoundException.class);

        verify(trashStore, never()).restore(any());
    }

    @Test
    void videoOutsideTrashCannotBeRestored() {
        when(videoRepository.findDeletedById(VIDEO)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.restore(VIDEO, OWNER)).isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void strangerCannotRestoreOrPurge() {
        when(videoRepository.findDeletedById(VIDEO)).thenReturn(Optional.of(video(LocalDateTime.now())));

        assertThatThrownBy(() -> service.restore(VIDEO, STRANGER)).isInstanceOf(AppException.class);
        assertThatThrownBy(() -> service.deletePermanently(VIDEO, STRANGER)).isInstanceOf(AppException.class);

        verify(trashStore, never()).restore(any());
        verify(trashStore, never()).hardDelete(any());
    }

    @Test
    void permanentDeleteRemovesRowsThenRequestsMediaCleanup() {
        when(videoRepository.findDeletedById(VIDEO)).thenReturn(Optional.of(video(LocalDateTime.now())));

        service.deletePermanently(VIDEO, OWNER);

        verify(trashStore).hardDelete(VIDEO);
        verify(eventPublisher).publishEvent(new VideoPurgedEvent(VIDEO_URL, THUMBNAIL_URL));
    }

    @Test
    void mediaStillUsedByAnotherVideoIsKept() {
        when(videoRepository.findDeletedById(VIDEO)).thenReturn(Optional.of(video(LocalDateTime.now())));
        when(trashStore.isMediaInUse(VIDEO_URL)).thenReturn(true);

        service.deletePermanently(VIDEO, OWNER);

        verify(eventPublisher).publishEvent(new VideoPurgedEvent(null, THUMBNAIL_URL));
    }

    @Test
    void jobPurgesVideoPastRetention() {
        when(videoRepository.findDeletedById(VIDEO))
                .thenReturn(Optional.of(video(LocalDateTime.now().minusDays(RETENTION_DAYS + 1))));

        service.purgeExpired(VIDEO);

        verify(trashStore).hardDelete(VIDEO);
    }

    @Test
    void jobSkipsVideoRestoredOrStillInRetention() {
        when(videoRepository.findDeletedById(VIDEO))
                .thenReturn(Optional.of(video(LocalDateTime.now().minusDays(RETENTION_DAYS - 1))));
        service.purgeExpired(VIDEO);

        when(videoRepository.findDeletedById(VIDEO)).thenReturn(Optional.empty());
        service.purgeExpired(VIDEO);

        verify(trashStore, never()).hardDelete(any());
    }

    private static Video video(LocalDateTime deletedAt) {
        return Video.builder().id(VIDEO).user(User.builder().id(OWNER).build())
                .videoUrl(VIDEO_URL).thumbnailUrl(THUMBNAIL_URL).deletedAt(deletedAt).build();
    }

    private static User user(long id, UserRole role) {
        return User.builder().id(id).role(role).build();
    }
}
