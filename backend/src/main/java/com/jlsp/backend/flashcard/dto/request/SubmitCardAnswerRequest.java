package com.jlsp.backend.flashcard.dto.request;

import jakarta.validation.constraints.NotNull;
import lombok.*;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class SubmitCardAnswerRequest {

    @NotNull(message = "Card ID is required")
    private Long cardId;

    @NotNull(message = "isCorrect is required")
    private Boolean isCorrect;
}
