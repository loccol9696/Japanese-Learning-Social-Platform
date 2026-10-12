package com.jlsp.backend.flashcard.dto.response;

import lombok.*;

import java.util.List;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class QuizQuestionResponse {

    private Long cardId;
    private String term;
    private String sinoVietnamese;
    private String meaning;
    private String correctAnswer;
    private List<String> options;
}
