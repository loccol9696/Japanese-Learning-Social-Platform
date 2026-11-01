package com.jlsp.backend.video.dto.response;

import lombok.*;

import java.util.List;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ShadowingSummaryResponse {

    private List<Line> lines;
    /** Số dòng đã luyện. */
    private int practicedLines;
    /** Trung bình điểm cao nhất của các dòng đã luyện, 0 nếu chưa luyện dòng nào. */
    private int averageScore;

    @Getter
    @AllArgsConstructor
    public static class Line {
        private final int lineIndex;
        private final int bestScore;
        private final int attempts;
    }
}
