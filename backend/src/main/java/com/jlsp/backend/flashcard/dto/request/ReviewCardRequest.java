package com.jlsp.backend.flashcard.dto.request;

import com.jlsp.backend.flashcard.srs.ReviewRating;
import jakarta.validation.constraints.NotNull;
import lombok.*;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ReviewCardRequest {

    @NotNull(message = "Card ID is required")
    private Long cardId;

    @NotNull(message = "rating is required")
    private ReviewRating rating;
}
