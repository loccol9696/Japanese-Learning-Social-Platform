package com.jlsp.backend.report.controller;

import com.jlsp.backend.common.response.ApiResponse;
import com.jlsp.backend.common.security.CurrentUser;
import com.jlsp.backend.report.dto.CreateReportRequest;
import com.jlsp.backend.report.dto.ReportResponse;
import com.jlsp.backend.report.service.ReportService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** Người dùng đăng nhập gửi báo cáo vi phạm. */
@RestController
@RequestMapping("/api/v1/reports")
@RequiredArgsConstructor
public class ReportController {

    private final ReportService reportService;

    @PostMapping
    public ResponseEntity<ApiResponse<ReportResponse>> create(@Valid @RequestBody CreateReportRequest request) {
        ReportResponse response = reportService.create(CurrentUser.requireId(), request);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.success(HttpStatus.CREATED.value(),
                        "Đã gửi báo cáo, cảm ơn bạn đã giúp cộng đồng an toàn hơn", response));
    }
}
