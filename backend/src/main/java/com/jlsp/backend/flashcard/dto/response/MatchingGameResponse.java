package com.jlsp.backend.flashcard.dto.response;

import lombok.*;

import java.util.List;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class MatchingGameResponse {

    private Long setId;
    private Integer totalPairs;
    private List<MatchingTile> tiles;

    @Getter
    @Setter
    @NoArgsConstructor
    @AllArgsConstructor
    @Builder
    public static class MatchingTile {
        private String tileId;
        private Long cardId;     // Match key: two tiles with same cardId are a pair
        private String text;       // e.g. "壊す" or "làm hỏng"
        private String type;       // "TERM" or "MEANING"
    }
}
