package com.jlsp.backend.video.service.impl;

import com.jlsp.backend.video.service.VideoTrashService;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class VideoTrashPurgeJobTest {

    @Test
    void oneFailedVideoDoesNotStopTheRest() {
        VideoTrashService service = mock(VideoTrashService.class);
        when(service.findExpiredIds()).thenReturn(List.of(1L, 2L, 3L));
        doThrow(new IllegalStateException("khóa ngoại")).when(service).purgeExpired(2L);

        new VideoTrashPurgeJob(service).purgeExpiredVideos();

        verify(service).purgeExpired(1L);
        verify(service).purgeExpired(2L);
        verify(service).purgeExpired(3L);
    }
}
