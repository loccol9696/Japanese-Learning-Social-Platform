package com.jlsp.backend.video.controller;

import com.jlsp.backend.common.response.ApiResponse;
import com.jlsp.backend.video.dto.response.HashtagSuggestionResponse;
import com.jlsp.backend.video.service.HashtagService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/v1/hashtags")
@RequiredArgsConstructor
public class HashtagController {

    private final HashtagService hashtagService;

    /**
     * Gợi ý hashtag khi người dùng gõ (màn đăng video, ô tìm kiếm).
     * GET /api/v1/hashtags/suggest?q=an&limit=8
     */
    @GetMapping("/suggest")
    public ResponseEntity<ApiResponse<List<HashtagSuggestionResponse>>> suggest(
            @RequestParam(value = "q", required = false, defaultValue = "") String query,
            @RequestParam(value = "limit", required = false, defaultValue = "8") int limit) {
        return ResponseEntity.ok(ApiResponse.success(hashtagService.suggest(query, limit)));
    }
}
