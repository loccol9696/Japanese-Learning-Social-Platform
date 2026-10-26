package com.jlsp.backend.flashcard.srs;

import org.junit.jupiter.api.Test;

import java.time.Duration;
import java.time.LocalDateTime;

import static org.assertj.core.api.Assertions.assertThat;

class SrsSchedulerTest {

    private static final LocalDateTime NOW = LocalDateTime.of(2026, 10, 24, 20, 0);

    @Test
    void againHardGoodKeepCardInLearningWithShortDelays() {
        var again = SrsScheduler.apply(CardState.NEW, 2.5, 0, ReviewRating.AGAIN, NOW);
        var hard = SrsScheduler.apply(CardState.NEW, 2.5, 0, ReviewRating.HARD, NOW);
        var good = SrsScheduler.apply(CardState.NEW, 2.5, 0, ReviewRating.GOOD, NOW);

        assertThat(again.graduated()).isFalse();
        assertThat(hard.graduated()).isFalse();
        assertThat(good.graduated()).isFalse();
        assertThat(Duration.between(NOW, again.nextReviewAt())).isEqualTo(Duration.ofMinutes(1));
        assertThat(Duration.between(NOW, hard.nextReviewAt())).isEqualTo(Duration.ofMinutes(5));
        assertThat(Duration.between(NOW, good.nextReviewAt())).isEqualTo(Duration.ofMinutes(10));
        assertThat(again.state()).isEqualTo(CardState.LEARNING);
    }

    @Test
    void firstEasyGraduatesForFourDays() {
        var easy = SrsScheduler.apply(CardState.NEW, 2.5, 0, ReviewRating.EASY, NOW);

        assertThat(easy.graduated()).isTrue();
        assertThat(easy.state()).isEqualTo(CardState.REVIEW);
        assertThat(easy.intervalDays()).isEqualTo(4);
        assertThat(easy.nextReviewAt()).isEqualTo(NOW.plusDays(4));
    }

    @Test
    void laterEasyMultipliesIntervalByEase() {
        var easy = SrsScheduler.apply(CardState.REVIEW, 2.5, 4, ReviewRating.EASY, NOW);
        assertThat(easy.intervalDays()).isEqualTo(10);
        assertThat(SrsScheduler.nextIntervalDays(10, 2.5)).isEqualTo(25);
    }

    @Test
    void intervalAlwaysGrowsEvenWithMinimumEase() {
        assertThat(SrsScheduler.nextIntervalDays(1, 1.3)).isEqualTo(2);
    }

    @Test
    void againOnReviewCardHalvesIntervalAndCountsLapse() {
        var again = SrsScheduler.apply(CardState.REVIEW, 2.5, 10, ReviewRating.AGAIN, NOW);

        assertThat(again.lapsed()).isTrue();
        assertThat(again.intervalDays()).isEqualTo(5);
        assertThat(again.easeFactor()).isEqualTo(2.3);
        assertThat(again.state()).isEqualTo(CardState.LEARNING);
    }

    @Test
    void againOnLearningCardIsNotALapse() {
        var again = SrsScheduler.apply(CardState.LEARNING, 2.5, 0, ReviewRating.AGAIN, NOW);
        assertThat(again.lapsed()).isFalse();
    }

    @Test
    void easeNeverDropsBelowMinimum() {
        double ease = 2.5;
        for (int i = 0; i < 30; i++) {
            ease = SrsScheduler.apply(CardState.LEARNING, ease, 0, ReviewRating.AGAIN, NOW).easeFactor();
        }
        assertThat(ease).isEqualTo(SrsScheduler.MIN_EASE);
    }

    @Test
    void previewLabelsMatchButtons() {
        var labels = SrsScheduler.previewLabels(CardState.NEW, 2.5, 0);
        assertThat(labels.get(ReviewRating.AGAIN)).isEqualTo("1 phút");
        assertThat(labels.get(ReviewRating.EASY)).isEqualTo("4 ngày");
    }
}
