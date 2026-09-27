package com.jlsp.backend.lesson.service;

import com.jlsp.backend.common.response.PageResponse;
import com.jlsp.backend.lesson.dto.request.CreateLessonRequest;
import com.jlsp.backend.lesson.dto.request.UpdateLessonRequest;
import com.jlsp.backend.lesson.dto.response.LessonResponse;
import com.jlsp.backend.lesson.entity.LessonCategory;
import com.jlsp.backend.user.entity.JLPTLevel;
import org.springframework.data.domain.Pageable;

public interface LessonService {

    LessonResponse createLesson(CreateLessonRequest request);

    LessonResponse getLessonById(Long id);

    PageResponse<LessonResponse> getAllLessons(JLPTLevel level, LessonCategory category, Pageable pageable);

    LessonResponse updateLesson(Long id, UpdateLessonRequest request);

    void deleteLesson(Long id);
}
