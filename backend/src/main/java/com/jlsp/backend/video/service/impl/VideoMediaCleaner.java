package com.jlsp.backend.video.service.impl;

import com.jlsp.backend.media.service.MediaService;
import com.jlsp.backend.video.event.VideoPurgedEvent;
import lombok.RequiredArgsConstructor;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

/** Gỡ file của video đã xóa hẳn khỏi cloud. */
@Component
@RequiredArgsConstructor
public class VideoMediaCleaner {

    private final MediaService mediaService;

    @Async
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void onVideoPurged(VideoPurgedEvent event) {
        mediaService.deleteByUrl(event.videoUrl());
        mediaService.deleteByUrl(event.thumbnailUrl());
    }
}
