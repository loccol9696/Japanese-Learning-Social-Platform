package com.jlsp.backend.topic.controller;

import com.jlsp.backend.common.response.ApiResponse;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/topics")
public class TopicController {

    private static final List<Map<String, Object>> DEFAULT_TOPICS = List.of(
            Map.of("id", 1, "name", "Anime & Manga"),
            Map.of("id", 2, "name", "Giao tiếp hằng ngày"),
            Map.of("id", 3, "name", "Luyện thi JLPT"),
            Map.of("id", 4, "name", "Văn hóa & Du lịch"),
            Map.of("id", 5, "name", "Âm nhạc J-Pop"),
            Map.of("id", 6, "name", "Ẩm thực Nhật Bản"),
            Map.of("id", 7, "name", "Kanji & Hán tự"),
            Map.of("id", 8, "name", "Công việc & IT"),
            Map.of("id", 9, "name", "Tin tức thời sự")
    );

    @GetMapping
    public ResponseEntity<ApiResponse<List<Map<String, Object>>>> getTopics() {
        return ResponseEntity.ok(ApiResponse.success(DEFAULT_TOPICS));
    }
}
