package com.jlsp.backend.flashcard.dto.response;

import lombok.*;

import java.time.LocalDateTime;
import java.util.Map;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ReviewResultResponse {

    private Long cardId;
    private String state;
    /** true khi bấm "Dễ": thẻ rời phiên học. */
    private boolean graduated;
    private int intervalDays;
    private LocalDateTime nextReviewAt;
    /** Nhãn mới dưới 4 nút cho lần xuất hiện kế tiếp của thẻ. */
    private Map<String, String> intervalLabels;
}
