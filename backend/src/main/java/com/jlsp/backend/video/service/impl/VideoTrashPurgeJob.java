package com.jlsp.backend.video.service.impl;

import com.jlsp.backend.video.service.VideoTrashService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.util.List;

/** Mỗi ngày xóa hẳn các video đã nằm trong thùng rác quá hạn lưu. */
@Component
@RequiredArgsConstructor
@Slf4j
public class VideoTrashPurgeJob {

    private final VideoTrashService videoTrashService;

    @Scheduled(cron = "${app.video.trash-purge-cron:0 30 3 * * *}")
    public void purgeExpiredVideos() {
        List<Long> expiredIds = videoTrashService.findExpiredIds();
        int failed = 0;
        for (Long videoId : expiredIds) {
            // Mỗi video một transaction: một video lỗi không chặn các video còn lại và sẽ thử lại lần sau.
            try {
                videoTrashService.purgeExpired(videoId);
            } catch (RuntimeException e) {
                failed++;
                log.error("Không thể xóa hẳn video ID: {}", videoId, e);
            }
        }
        if (!expiredIds.isEmpty()) {
            log.info("Dọn thùng rác: đã xóa hẳn {}/{} video", expiredIds.size() - failed, expiredIds.size());
        }
    }
}
