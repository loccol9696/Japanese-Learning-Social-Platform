package com.jlsp.backend.lesson.mapper;

import com.jlsp.backend.lesson.dto.request.CreateLessonRequest;
import com.jlsp.backend.lesson.dto.response.LessonResponse;
import com.jlsp.backend.lesson.entity.Lesson;
import org.springframework.stereotype.Component;

@Component
public class LessonMapper {

    public LessonResponse toResponse(Lesson entity) {
        if (entity == null) {
            return null;
        }
        return LessonResponse.builder()
                .id(entity.getId())
                .title(entity.getTitle())
                .content(entity.getContent())
                .level(entity.getLevel())
                .category(entity.getCategory())
                .createdBy(entity.getCreatedBy())
                .createdAt(entity.getCreatedAt())
                .updatedAt(entity.getUpdatedAt())
                .build();
    }

    public Lesson toEntity(CreateLessonRequest request) {
        if (request == null) {
            return null;
        }
        return Lesson.builder()
                .title(request.getTitle())
                .content(request.getContent())
                .level(request.getLevel())
                .category(request.getCategory())
                .build();
    }
}
