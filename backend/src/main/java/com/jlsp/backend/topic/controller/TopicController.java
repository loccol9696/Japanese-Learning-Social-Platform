package com.jlsp.backend.topic.controller;

import com.jlsp.backend.common.response.ApiResponse;
import com.jlsp.backend.topic.dto.TopicRequest;
import com.jlsp.backend.topic.dto.TopicResponse;
import com.jlsp.backend.topic.service.TopicService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping({"/api/v1/topics", "/topics"})
@RequiredArgsConstructor
public class TopicController {

    private final TopicService topicService;

    /** Chủ đề đang hiển thị (công khai). */
    @GetMapping
    public ResponseEntity<ApiResponse<List<TopicResponse>>> getTopics() {
        return ResponseEntity.ok(ApiResponse.success(topicService.getActiveTopics()));
    }

    /** Toàn bộ chủ đề kể cả đã ẩn (ADMIN). */
    @GetMapping("/admin")
    public ResponseEntity<ApiResponse<List<TopicResponse>>> getAllTopics() {
        return ResponseEntity.ok(ApiResponse.success(topicService.getAllTopics()));
    }

    @PostMapping("/admin")
    public ResponseEntity<ApiResponse<TopicResponse>> create(@Valid @RequestBody TopicRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.success(HttpStatus.CREATED.value(), "Tạo chủ đề thành công",
                        topicService.create(request)));
    }

    @PutMapping("/admin/{id}")
    public ResponseEntity<ApiResponse<TopicResponse>> update(
            @PathVariable Long id, @Valid @RequestBody TopicRequest request) {
        return ResponseEntity.ok(ApiResponse.success(200, "Cập nhật chủ đề thành công",
                topicService.update(id, request)));
    }

    /** Ẩn chủ đề (xoá mềm, không làm mất liên kết với video / hồ sơ). */
    @DeleteMapping("/admin/{id}")
    public ResponseEntity<ApiResponse<Void>> deactivate(@PathVariable Long id) {
        topicService.deactivate(id);
        return ResponseEntity.ok(ApiResponse.success(200, "Đã ẩn chủ đề", null));
    }
}
