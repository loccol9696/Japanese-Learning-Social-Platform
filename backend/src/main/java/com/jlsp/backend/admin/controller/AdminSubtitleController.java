package com.jlsp.backend.admin.controller;

import com.jlsp.backend.common.response.ApiResponse;
import com.jlsp.backend.video.service.impl.SubtitleResplitService;
import com.jlsp.backend.video.service.impl.SubtitleResplitService.VideoResult;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

/** Công cụ quản trị cho phụ đề video (chỉ ADMIN, xem SecurityConfig). */
@RestController
@RequestMapping("/api/v1/admin/subtitles")
public class AdminSubtitleController {

    private final SubtitleResplitService resplitService;

    public AdminSubtitleController(SubtitleResplitService resplitService) {
        this.resplitService = resplitService;
    }

    /**
     * Tách lại phụ đề dài của video cũ thành câu ngắn.
     * POST /api/v1/admin/subtitles/resplit?dryRun=true[&videoId=123]
     * Mặc định dryRun=true: chỉ báo cáo, không ghi database.
     */
    @PostMapping("/resplit")
    public ResponseEntity<ApiResponse<List<VideoResult>>> resplit(
            @RequestParam(required = false) Long videoId,
            @RequestParam(defaultValue = "true") boolean dryRun) {
        return ResponseEntity.ok(ApiResponse.success(resplitService.resplit(videoId, dryRun)));
    }
}
