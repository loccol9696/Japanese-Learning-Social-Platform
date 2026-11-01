package com.jlsp.backend.report.dto;

import com.jlsp.backend.report.entity.ReportReason;
import com.jlsp.backend.report.entity.ReportStatus;
import com.jlsp.backend.report.entity.ReportTargetType;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

/**
 * Kết quả báo cáo cho người dùng thường xem. Tách khỏi {@link ReportResponse} (dành cho kiểm duyệt viên) để
 * không lộ danh tính người báo cáo, người xử lý hay số lần vi phạm của người khác.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ReportResultResponse {
    private Long id;
    private ReportTargetType targetType;
    /** Nguyên văn nội dung lúc báo cáo; null nếu không còn gì để hiển thị. */
    private String content;
    private ReportReason reason;
    /** Mô tả người báo cáo đã gửi; chỉ người báo cáo mới thấy. */
    private String detail;
    private ReportStatus status;
    /** Kết quả xử lý, viết sẵn theo góc nhìn của người xem. */
    private String outcome;
    /** Ghi chú của kiểm duyệt viên dành cho người xem, null nếu không có. */
    private String note;
    private LocalDateTime createdAt;
    private LocalDateTime resolvedAt;
}
