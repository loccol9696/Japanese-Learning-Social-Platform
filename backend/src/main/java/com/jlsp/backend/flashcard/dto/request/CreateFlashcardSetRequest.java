package com.jlsp.backend.flashcard.dto.request;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Size;
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
    @Size(max = 255, message = "Tiêu đề tối đa 255 ký tự")
    private String title;

    @Size(max = 5000, message = "Mô tả tối đa 5000 ký tự")
    private String description;

    private Boolean isPublic;

    @Valid
    @Size(max = 2000, message = "Một bộ thẻ tối đa 2000 thẻ")
    private List<CreateFlashcardRequest> cards;
}
