package com.jlsp.backend.notification.service;

import com.jlsp.backend.notification.repository.NotificationRepository;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;

/**
 * Dọn thông báo cũ để bảng không phình mãi: thông báo đã đọc quá {@code notification.retention.read-days}
 * (mặc định 90) ngày, và mọi thông báo quá {@code notification.retention.max-days} (mặc định 180) ngày kể cả
 * chưa đọc. Chạy mỗi đêm; nhiều instance cùng chạy cũng không sao vì thao tác xoá lặp lại là vô hại.
 */
@Component
@Slf4j
public class NotificationCleanupJob {

    private final NotificationRepository repository;
    private final int readRetentionDays;
    private final int maxRetentionDays;

    public NotificationCleanupJob(
            NotificationRepository repository,
            @Value("${notification.retention.read-days:90}") int readRetentionDays,
            @Value("${notification.retention.max-days:180}") int maxRetentionDays) {
        this.repository = repository;
        this.readRetentionDays = Math.max(1, readRetentionDays);
        // Thông báo chưa đọc không được bị xoá sớm hơn thông báo đã đọc.
        this.maxRetentionDays = Math.max(this.readRetentionDays, maxRetentionDays);
    }

    @Scheduled(cron = "${notification.retention.cron:0 30 3 * * *}")
    @Transactional
    public void purgeScheduled() {
        purge(LocalDateTime.now());
    }

    /** @return tổng số thông báo đã xoá */
    int purge(LocalDateTime now) {
        int read = repository.deleteReadBefore(now.minusDays(readRetentionDays));
        int old = repository.deleteAllBefore(now.minusDays(maxRetentionDays));
        if (read + old > 0) {
            log.info("Đã dọn {} thông báo đã đọc cũ và {} thông báo quá hạn.", read, old);
        }
        return read + old;
    }
}
