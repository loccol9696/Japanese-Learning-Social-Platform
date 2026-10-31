package com.jlsp.backend.flashcard.dto.request;

import jakarta.validation.constraints.Size;
import jakarta.validation.constraints.NotBlank;
import lombok.*;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class CreateFlashcardRequest {

    @NotBlank(message = "Term is required")
    @Size(max = 255, message = "Từ tối đa 255 ký tự")
    private String term;

    @Size(max = 255, message = "Cách đọc tối đa 255 ký tự")
    private String reading;

    @Size(max = 100, message = "Hán Việt tối đa 100 ký tự")
    private String sinoVietnamese;

    @NotBlank(message = "Meaning is required")
    @Size(max = 5000, message = "Nghĩa tối đa 5000 ký tự")
    private String meaning;

    @Size(max = 5000, message = "Ví dụ tối đa 5000 ký tự")
    private String example;

    @Size(max = 500, message = "Đường dẫn âm thanh tối đa 500 ký tự")
    private String audioUrl;
}
