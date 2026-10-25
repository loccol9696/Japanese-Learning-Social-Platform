package com.jlsp.backend.video.dto.response;

import lombok.*;

import java.util.List;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ShadowingLineScoreResponse {

    private int lineIndex;
    private String expectedText;
    private String recognizedText;
    /** 0-100 */
    private int score;
    /** EXCELLENT / GOOD / FAIR / TRY_AGAIN */
    private String level;
    private List<Word> words;
    /** Điểm cao nhất của dòng này (kể cả lần vừa chấm). */
    private int bestScore;

    @Getter
    @AllArgsConstructor
    public static class Word {
        private final String text;
        private final boolean correct;
    }
}
