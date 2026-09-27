package com.jlsp.backend.lesson.dto.request;

import com.jlsp.backend.lesson.entity.LessonCategory;
import com.jlsp.backend.user.entity.JLPTLevel;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CreateLessonRequest {

    @NotBlank(message = "Title is required")
    @Size(max = 200, message = "Title must be at most 200 characters")
    private String title;

    private String content;

    @NotNull(message = "JLPT level is required")
    private JLPTLevel level;

    @NotNull(message = "Lesson category is required")
    private LessonCategory category;
}
