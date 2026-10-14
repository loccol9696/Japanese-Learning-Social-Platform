package com.jlsp.backend.flashcard.dto.request;

import jakarta.validation.constraints.NotBlank;
import lombok.*;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class SaveVideoVocabRequest {

    @NotBlank(message = "Term is required")
    private String term;

    private String reading;

    private String sinoVietnamese;

    @NotBlank(message = "Meaning is required")
    private String meaning;

    private String example;

    private Long videoId;
}
