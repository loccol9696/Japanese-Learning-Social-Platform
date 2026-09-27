package com.jlsp.backend.lesson.service.impl;

import com.jlsp.backend.common.response.PageResponse;
import com.jlsp.backend.lesson.dto.request.CreateLessonRequest;
import com.jlsp.backend.lesson.dto.request.UpdateLessonRequest;
import com.jlsp.backend.lesson.dto.response.LessonResponse;
import com.jlsp.backend.lesson.entity.LessonCategory;
import com.jlsp.backend.lesson.service.LessonService;
import com.jlsp.backend.user.entity.JLPTLevel;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
@Slf4j
public class LessonServiceImpl implements LessonService {

    @Override
    public LessonResponse createLesson(CreateLessonRequest request) {
        return null;
    }

    @Override
    public LessonResponse getLessonById(Long id) {
        return null;
    }

    @Override
    public PageResponse<LessonResponse> getAllLessons(JLPTLevel level, LessonCategory category, Pageable pageable) {
        return null;
    }

    @Override
    public LessonResponse updateLesson(Long id, UpdateLessonRequest request) {
        return null;
    }

    @Override
    public void deleteLesson(Long id) {
        // TODO: Implement
    }
}
