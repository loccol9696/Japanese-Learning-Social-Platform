package com.jlsp.backend.lesson.dto.request;

import com.jlsp.backend.lesson.entity.LessonCategory;
import com.jlsp.backend.user.entity.JLPTLevel;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class UpdateLessonRequest {

    @Size(max = 200, message = "Title must be at most 200 characters")
    private String title;

    private String content;

    private JLPTLevel level;

    private LessonCategory category;
}
