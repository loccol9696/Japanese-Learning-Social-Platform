package com.jlsp.backend.streak.service;

import com.jlsp.backend.streak.dto.StreakResponse;
import com.jlsp.backend.streak.entity.UserStreak;
import com.jlsp.backend.streak.repository.UserStreakRepository;
import org.junit.jupiter.api.Test;
import org.springframework.transaction.PlatformTransactionManager;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.mockito.Mockito.doThrow;

class StreakServiceTest {

    private static final long USER = 7L;
    private static final LocalDate TODAY = LocalDate.of(2026, 10, 27);

    private final UserStreakRepository repository = mock(UserStreakRepository.class);

    private static UserStreak streak(int current, int longest, LocalDate last) {
        return UserStreak.builder().userId(USER).currentStreak(current).longestStreak(longest).lastActiveDate(last).build();
    }

    /** Đồng hồ cố định: 12:00 giờ Việt Nam ngày TODAY. */
    private StreakService service() {
        Clock clock = Clock.fixed(Instant.parse("2026-10-27T05:00:00Z"), StreakService.ZONE);
        return new StreakService(repository, mock(PlatformTransactionManager.class), clock);
    }

    // ---- quy tắc tính

    @Test
    void firstActivityStartsAStreakOfOne() {
        UserStreak s = streak(0, 0, null);
        StreakCalculator.recordActivity(s, TODAY);

        assertThat(s.getCurrentStreak()).isEqualTo(1);
        assertThat(s.getLongestStreak()).isEqualTo(1);
        assertThat(s.getLastActiveDate()).isEqualTo(TODAY);
    }

    @Test
    void activityOnConsecutiveDayExtendsTheStreakAndLongest() {
        UserStreak s = streak(4, 4, TODAY.minusDays(1));
        StreakCalculator.recordActivity(s, TODAY);

        assertThat(s.getCurrentStreak()).isEqualTo(5);
        assertThat(s.getLongestStreak()).isEqualTo(5);
    }

    @Test
    void secondActivityOnTheSameDayChangesNothing() {
        UserStreak s = streak(3, 9, TODAY);
        StreakCalculator.recordActivity(s, TODAY);

        assertThat(s.getCurrentStreak()).isEqualTo(3);
        assertThat(s.getLongestStreak()).isEqualTo(9);
    }

    @Test
    void missingADayRestartsAtOneButKeepsLongest() {
        UserStreak s = streak(6, 6, TODAY.minusDays(2));
        StreakCalculator.recordActivity(s, TODAY);

        assertThat(s.getCurrentStreak()).isEqualTo(1);
        assertThat(s.getLongestStreak()).isEqualTo(6);
    }

    @Test
    void lastActiveDateInTheFutureIsIgnored() {
        UserStreak s = streak(3, 3, TODAY.plusDays(1));
        StreakCalculator.recordActivity(s, TODAY);

        assertThat(s.getCurrentStreak()).isEqualTo(3);
        assertThat(s.getLastActiveDate()).isEqualTo(TODAY.plusDays(1));
    }

    @Test
    void effectiveStreakIsKeptForTodayAndYesterdayOnly() {
        assertThat(StreakCalculator.effectiveStreak(streak(5, 5, TODAY), TODAY)).isEqualTo(5);
        assertThat(StreakCalculator.effectiveStreak(streak(5, 5, TODAY.minusDays(1)), TODAY)).isEqualTo(5);
        assertThat(StreakCalculator.effectiveStreak(streak(5, 5, TODAY.minusDays(2)), TODAY)).isZero();
        assertThat(StreakCalculator.effectiveStreak(streak(0, 0, null), TODAY)).isZero();
    }

    // ---- service

    @Test
    void recordActivityLocksTheRowAndSavesTheNewStreak() {
        UserStreak existing = streak(2, 2, TODAY.minusDays(1));
        when(repository.findForUpdate(USER)).thenReturn(Optional.of(existing));

        service().recordActivity(USER);

        verify(repository).insertIfAbsent(USER);
        verify(repository).save(existing);
        assertThat(existing.getCurrentStreak()).isEqualTo(3);
    }

    @Test
    void recordActivityNeverPropagatesFailures() {
        doThrow(new IllegalStateException("db down")).when(repository).insertIfAbsent(USER);

        service().recordActivity(USER); // không ném

        verify(repository, never()).save(any());
    }

    @Test
    void recordActivityIgnoresNullUser() {
        service().recordActivity(null);

        verify(repository, never()).insertIfAbsent(any());
    }

    @Test
    void getReturnsZerosForUsersWhoNeverStudied() {
        when(repository.findById(USER)).thenReturn(Optional.empty());

        StreakResponse r = service().get(USER);

        assertThat(r.getCurrentStreak()).isZero();
        assertThat(r.isActiveToday()).isFalse();
    }

    @Test
    void getReportsActiveTodayAndDropsStaleStreak() {
        when(repository.findById(USER)).thenReturn(Optional.of(streak(4, 8, TODAY)));
        assertThat(service().get(USER).isActiveToday()).isTrue();
        assertThat(service().get(USER).getCurrentStreak()).isEqualTo(4);

        when(repository.findById(USER)).thenReturn(Optional.of(streak(4, 8, TODAY.minusDays(3))));
        StreakResponse stale = service().get(USER);
        assertThat(stale.getCurrentStreak()).isZero();
        assertThat(stale.getLongestStreak()).isEqualTo(8);
    }
}
