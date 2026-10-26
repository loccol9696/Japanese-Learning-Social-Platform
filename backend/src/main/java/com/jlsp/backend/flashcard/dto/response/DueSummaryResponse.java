package com.jlsp.backend.flashcard.dto.response;

import lombok.*;

import java.time.LocalDateTime;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class DueSummaryResponse {

    /** Số thẻ đã tới hạn ôn (mọi bộ). */
    private long dueCount;
    /** Thời điểm đến hạn gần nhất trong tương lai, null nếu không có. */
    private LocalDateTime nextDueAt;
    /** Số thẻ sẽ đến hạn trong 24 giờ kể từ [nextDueAt]. */
    private long dueAtNextCount;
}
