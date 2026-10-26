package com.jlsp.backend.flashcard.srs;

import java.time.Duration;
import java.time.LocalDateTime;
import java.util.EnumMap;
import java.util.Map;

/**
 * Thuật toán học ngắt quãng (SM-2 rút gọn), thuần hàm để dễ kiểm thử.
 *
 * <ul>
 *   <li>Xem lại / Khó / Ổn: thẻ vẫn đang học, quay lại phiên sau 1 / 5 / 10 phút.</li>
 *   <li>Dễ: thẻ rời phiên; lần đầu hẹn {@value #FIRST_INTERVAL_DAYS} ngày, các lần sau nhân hệ số dễ.</li>
 * </ul>
 */
public final class SrsScheduler {

    public static final double DEFAULT_EASE = 2.5;
    public static final double MIN_EASE = 1.3;
    public static final int FIRST_INTERVAL_DAYS = 4;

    private static final Duration AGAIN_DELAY = Duration.ofMinutes(1);
    private static final Duration HARD_DELAY = Duration.ofMinutes(5);
    private static final Duration GOOD_DELAY = Duration.ofMinutes(10);

    private SrsScheduler() {
    }

    public static CardSchedule apply(CardState state, double easeFactor, int intervalDays,
                                     ReviewRating rating, LocalDateTime now) {
        boolean wasReview = state == CardState.REVIEW;
        double ease = easeFactor > 0 ? easeFactor : DEFAULT_EASE;

        return switch (rating) {
            case AGAIN -> new CardSchedule(
                    CardState.LEARNING,
                    round(Math.max(MIN_EASE, ease - 0.2)),
                    wasReview ? Math.max(1, intervalDays / 2) : intervalDays,
                    now.plus(AGAIN_DELAY),
                    false,
                    wasReview);
            case HARD -> new CardSchedule(
                    CardState.LEARNING,
                    round(Math.max(MIN_EASE, ease - 0.15)),
                    intervalDays,
                    now.plus(HARD_DELAY),
                    false,
                    false);
            case GOOD -> new CardSchedule(
                    CardState.LEARNING,
                    ease,
                    intervalDays,
                    now.plus(GOOD_DELAY),
                    false,
                    false);
            case EASY -> {
                int next = nextIntervalDays(intervalDays, ease);
                yield new CardSchedule(CardState.REVIEW, ease, next, now.plusDays(next), true, false);
            }
        };
    }

    /** Khoảng cách (ngày) sau khi bấm "Dễ". */
    public static int nextIntervalDays(int currentIntervalDays, double easeFactor) {
        if (currentIntervalDays <= 0) {
            return FIRST_INTERVAL_DAYS;
        }
        int grown = (int) Math.round(currentIntervalDays * easeFactor);
        return Math.max(currentIntervalDays + 1, grown);
    }

    /** Nhãn thời gian hiển thị dưới 4 nút, ví dụ "1 phút", "4 ngày". */
    public static Map<ReviewRating, String> previewLabels(CardState state, double easeFactor, int intervalDays) {
        double ease = easeFactor > 0 ? easeFactor : DEFAULT_EASE;
        Map<ReviewRating, String> labels = new EnumMap<>(ReviewRating.class);
        labels.put(ReviewRating.AGAIN, "1 phút");
        labels.put(ReviewRating.HARD, "5 phút");
        labels.put(ReviewRating.GOOD, "10 phút");
        labels.put(ReviewRating.EASY, nextIntervalDays(intervalDays, ease) + " ngày");
        return labels;
    }

    private static double round(double v) {
        return Math.round(v * 100.0) / 100.0;
    }
}
