package com.jlsp.backend.lesson.dto.response;

import com.jlsp.backend.lesson.entity.LessonCategory;
import com.jlsp.backend.user.entity.JLPTLevel;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class LessonResponse {

    private Long id;
    private String title;
    private String content;
    private JLPTLevel level;
    private LessonCategory category;
    private Long createdBy;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}
