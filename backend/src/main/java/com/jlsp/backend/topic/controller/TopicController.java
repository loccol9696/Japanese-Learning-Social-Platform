package com.jlsp.backend.topic.controller;

import com.jlsp.backend.common.response.ApiResponse;
import com.jlsp.backend.topic.dto.response.TopicResponse;
import com.jlsp.backend.topic.service.TopicService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping({"/api/v1/topics", "/topics"})
@RequiredArgsConstructor
public class TopicController {

    private final TopicService topicService;

    @GetMapping
    public ResponseEntity<ApiResponse<List<TopicResponse>>> getAllTopics() {
        List<TopicResponse> topics = topicService.getAllTopics();
        return ResponseEntity.ok(ApiResponse.success(topics));
    }

    @PostMapping
    public ResponseEntity<ApiResponse<TopicResponse>> createTopic(@RequestParam String name) {
        TopicResponse created = topicService.createTopic(name);
        return ResponseEntity.ok(ApiResponse.success(201, "Topic created successfully", created));
    }
}
