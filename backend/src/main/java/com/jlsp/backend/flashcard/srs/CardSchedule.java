package com.jlsp.backend.flashcard.srs;

import java.time.LocalDateTime;

/** Trạng thái lịch ôn của một thẻ sau khi áp dụng một mức đánh giá. */
public record CardSchedule(
        CardState state,
        double easeFactor,
        int intervalDays,
        LocalDateTime nextReviewAt,
        boolean graduated,
        boolean lapsed) {
}
