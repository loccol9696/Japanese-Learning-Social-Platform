package com.jlsp.backend.flashcard.dto.request;

import jakarta.validation.constraints.NotNull;
import lombok.*;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class UpdateCardStarRequest {

    @NotNull(message = "isStarred status is required")
    private Boolean isStarred;
}
