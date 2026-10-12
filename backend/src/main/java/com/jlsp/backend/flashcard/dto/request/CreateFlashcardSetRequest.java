package com.jlsp.backend.flashcard.dto.request;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import lombok.*;

import java.util.List;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class CreateFlashcardSetRequest {

    @NotBlank(message = "Title is required")
    private String title;

    private String description;

    private Boolean isPublic;

    @Valid
    private List<CreateFlashcardRequest> cards;
}
