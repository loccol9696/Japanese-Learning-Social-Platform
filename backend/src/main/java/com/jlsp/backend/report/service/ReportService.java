package com.jlsp.backend.report.service;

import com.jlsp.backend.common.response.PageResponse;
import com.jlsp.backend.report.dto.CreateReportRequest;
import com.jlsp.backend.report.dto.ReportResponse;
import com.jlsp.backend.report.dto.ResolveReportRequest;
import com.jlsp.backend.report.entity.ReportStatus;
import com.jlsp.backend.report.entity.ReportTargetType;
import org.springframework.data.domain.Pageable;

public interface ReportService {

    /** Người dùng gửi báo cáo; không báo cáo nội dung của chính mình, không gửi trùng khi báo cáo cũ còn chờ. */
    ReportResponse create(Long reporterId, CreateReportRequest request);

    /** Danh sách báo cáo cho Admin / Moderator; {@code targetType} null = mọi loại. */
    PageResponse<ReportResponse> list(ReportStatus status, ReportTargetType targetType, Pageable pageable);

    /**
     * Xử lý báo cáo kèm hành động; áp dụng cho MỌI báo cáo đang chờ của cùng đối tượng.
     * Khóa tài khoản chỉ dành cho Admin.
     */
    ReportResponse resolve(Long reportId, Long actorId, boolean actorIsAdmin, ResolveReportRequest request);

    /** Bác bỏ báo cáo (không vi phạm); áp dụng cho mọi báo cáo đang chờ của cùng đối tượng. */
    ReportResponse dismiss(Long reportId, Long actorId, String note);
}
