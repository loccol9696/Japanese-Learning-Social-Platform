package com.jlsp.backend.report.controller;

import com.jlsp.backend.common.response.ApiResponse;
import com.jlsp.backend.common.response.PageResponse;
import com.jlsp.backend.common.security.AuthUser;
import com.jlsp.backend.common.security.CurrentUser;
import com.jlsp.backend.report.dto.DismissReportRequest;
import com.jlsp.backend.report.dto.ReportResponse;
import com.jlsp.backend.report.dto.ResolveReportRequest;
import com.jlsp.backend.report.entity.ReportStatus;
import com.jlsp.backend.report.entity.ReportTargetType;
import com.jlsp.backend.report.service.ReportService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

/** Admin và Moderator xử lý báo cáo (phân quyền ở SecurityConfig). */
@RestController
@RequestMapping("/api/v1/admin/reports")
@RequiredArgsConstructor
public class AdminReportController {

    private final ReportService reportService;

    @GetMapping
    public ResponseEntity<ApiResponse<PageResponse<ReportResponse>>> list(
            @RequestParam(value = "status", required = false) ReportStatus status,
            @RequestParam(value = "targetType", required = false) ReportTargetType targetType,
            @PageableDefault(size = 10, sort = "createdAt", direction = Sort.Direction.DESC) Pageable pageable) {
        return ResponseEntity.ok(ApiResponse.success(reportService.list(status, targetType, pageable)));
    }

    @PostMapping("/{id}/resolve")
    public ResponseEntity<ApiResponse<ReportResponse>> resolve(
            @PathVariable Long id, @Valid @RequestBody ResolveReportRequest request) {
        AuthUser actor = CurrentUser.require();
        ReportResponse response = reportService.resolve(id, actor.id(), actor.hasRole("ADMIN"), request);
        return ResponseEntity.ok(ApiResponse.success(200, "Đã xử lý báo cáo", response));
    }

    @PostMapping("/{id}/dismiss")
    public ResponseEntity<ApiResponse<ReportResponse>> dismiss(
            @PathVariable Long id, @Valid @RequestBody(required = false) DismissReportRequest request) {
        ReportResponse response = reportService.dismiss(
                id, CurrentUser.requireId(), request == null ? null : request.getNote());
        return ResponseEntity.ok(ApiResponse.success(200, "Đã bác bỏ báo cáo", response));
    }
}
