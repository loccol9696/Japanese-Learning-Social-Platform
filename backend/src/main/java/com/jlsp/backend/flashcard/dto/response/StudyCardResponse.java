package com.jlsp.backend.flashcard.dto.response;

import lombok.*;

import java.util.Map;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class StudyCardResponse {

    private FlashcardResponse card;
    /** NEW / LEARNING / REVIEW */
    private String state;
    /** Nhãn thời gian dưới từng nút: AGAIN, HARD, GOOD, EASY. */
    private Map<String, String> intervalLabels;
}
