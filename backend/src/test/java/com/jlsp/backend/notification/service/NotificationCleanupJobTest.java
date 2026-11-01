package com.jlsp.backend.notification.service;

import com.jlsp.backend.notification.repository.NotificationRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import java.time.LocalDateTime;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class NotificationCleanupJobTest {

    private static final LocalDateTime NOW = LocalDateTime.of(2026, 10, 27, 3, 30);

    private NotificationRepository repository;

    @BeforeEach
    void setUp() {
        repository = mock(NotificationRepository.class);
    }

    @Test
    void deletesReadNotificationsOlderThanNinetyDaysAndAnythingOlderThanOneEightyByDefault() {
        NotificationCleanupJob job = new NotificationCleanupJob(repository, 90, 180);
        when(repository.deleteReadBefore(any())).thenReturn(7);
        when(repository.deleteAllBefore(any())).thenReturn(2);

        int deleted = job.purge(NOW);

        assertThat(deleted).isEqualTo(9);
        ArgumentCaptor<LocalDateTime> read = ArgumentCaptor.forClass(LocalDateTime.class);
        ArgumentCaptor<LocalDateTime> all = ArgumentCaptor.forClass(LocalDateTime.class);
        verify(repository).deleteReadBefore(read.capture());
        verify(repository).deleteAllBefore(all.capture());
        assertThat(read.getValue()).isEqualTo(NOW.minusDays(90));
        assertThat(all.getValue()).isEqualTo(NOW.minusDays(180));
    }

    @Test
    void unreadNotificationsAreNeverDeletedSoonerThanReadOnes() {
        // Cấu hình sai (tối đa nhỏ hơn thời hạn thông báo đã đọc) được nâng lên bằng nhau.
        NotificationCleanupJob job = new NotificationCleanupJob(repository, 60, 10);

        job.purge(NOW);

        ArgumentCaptor<LocalDateTime> all = ArgumentCaptor.forClass(LocalDateTime.class);
        verify(repository).deleteAllBefore(all.capture());
        assertThat(all.getValue()).isEqualTo(NOW.minusDays(60));
    }

    @Test
    void nonPositiveRetentionIsRaisedToOneDayInsteadOfWipingTheTable() {
        NotificationCleanupJob job = new NotificationCleanupJob(repository, 0, -5);

        job.purge(NOW);

        ArgumentCaptor<LocalDateTime> read = ArgumentCaptor.forClass(LocalDateTime.class);
        verify(repository).deleteReadBefore(read.capture());
        assertThat(read.getValue()).isEqualTo(NOW.minusDays(1));
    }

    @Test
    void scheduledRunUsesTheCurrentTime() {
        NotificationCleanupJob job = new NotificationCleanupJob(repository, 90, 180);
        LocalDateTime before = LocalDateTime.now();

        job.purgeScheduled();

        ArgumentCaptor<LocalDateTime> read = ArgumentCaptor.forClass(LocalDateTime.class);
        verify(repository).deleteReadBefore(read.capture());
        assertThat(read.getValue()).isBetween(before.minusDays(90).minusSeconds(1),
                LocalDateTime.now().minusDays(90).plusSeconds(1));
    }
}
