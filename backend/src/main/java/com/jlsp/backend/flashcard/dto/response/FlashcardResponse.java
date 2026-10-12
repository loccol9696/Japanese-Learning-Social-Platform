package com.jlsp.backend.flashcard.dto.response;

import lombok.*;

import java.time.LocalDateTime;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class FlashcardResponse {

    private Long cardId;
    private Long setId;
    private String term;
    private String reading;
    private String sinoVietnamese;
    private String meaning;
    private String example;
    private String audioUrl;
    private Boolean isStarred;
    private Integer boxLevel;
    private Integer correctCount;
    private Integer incorrectCount;
    private LocalDateTime nextReviewAt;
}
