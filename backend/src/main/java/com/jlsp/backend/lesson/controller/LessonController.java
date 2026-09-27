package com.jlsp.backend.lesson.controller;

import com.jlsp.backend.common.response.ApiResponse;
import com.jlsp.backend.common.response.PageResponse;
import com.jlsp.backend.lesson.dto.request.CreateLessonRequest;
import com.jlsp.backend.lesson.dto.request.UpdateLessonRequest;
import com.jlsp.backend.lesson.dto.response.LessonResponse;
import com.jlsp.backend.lesson.entity.LessonCategory;
import com.jlsp.backend.lesson.service.LessonService;
import com.jlsp.backend.user.entity.JLPTLevel;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/lessons")
@RequiredArgsConstructor
public class LessonController {

    private final LessonService lessonService;

    @PostMapping
    public ResponseEntity<ApiResponse<LessonResponse>> createLesson(@Valid @RequestBody CreateLessonRequest request) {
        LessonResponse response = lessonService.createLesson(request);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.success(HttpStatus.CREATED.value(), "Lesson created successfully", response));
    }

    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<LessonResponse>> getLessonById(@PathVariable Long id) {
        LessonResponse response = lessonService.getLessonById(id);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    @GetMapping
    public ResponseEntity<ApiResponse<PageResponse<LessonResponse>>> getAllLessons(
            @RequestParam(required = false) JLPTLevel level,
            @RequestParam(required = false) LessonCategory category,
            @PageableDefault(size = 10, sort = "createdAt") Pageable pageable) {
        PageResponse<LessonResponse> response = lessonService.getAllLessons(level, category, pageable);
        return ResponseEntity.ok(ApiResponse.success(response));
    }

    @PutMapping("/{id}")
    public ResponseEntity<ApiResponse<LessonResponse>> updateLesson(
            @PathVariable Long id,
            @Valid @RequestBody UpdateLessonRequest request) {
        LessonResponse response = lessonService.updateLesson(id, request);
        return ResponseEntity.ok(ApiResponse.success(200, "Lesson updated successfully", response));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<ApiResponse<Void>> deleteLesson(@PathVariable Long id) {
        lessonService.deleteLesson(id);
        return ResponseEntity.ok(ApiResponse.success(200, "Lesson deleted successfully", null));
    }
}
