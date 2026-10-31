package com.jlsp.backend.report.dto;

import com.jlsp.backend.report.entity.ReportAction;
import com.jlsp.backend.report.entity.ReportReason;
import com.jlsp.backend.report.entity.ReportStatus;
import com.jlsp.backend.report.entity.ReportTargetType;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ReportResponse {
    private Long id;
    private ReportTargetType targetType;
    private Long targetId;
    private ReportReason reason;
    private String detail;
    private ReportStatus status;
    private ReportAction action;
    private String resolutionNote;
    private Long resolvedBy;
    private LocalDateTime resolvedAt;
    private LocalDateTime createdAt;

    private Long reporterId;
    private String reporterUsername;

    /** Đối tượng còn tồn tại không (có thể đã bị xóa sau khi báo cáo). */
    private Boolean targetExists;
    /** Tiêu đề video / nội dung bình luận (rút gọn) / username. */
    private String targetSummary;
    /** Chủ nội dung bị báo cáo. */
    private Long targetOwnerId;
    private String targetOwnerUsername;
    /** Với bình luận: video chứa bình luận đó. */
    private Long targetVideoId;
    /** Số báo cáo đang chờ xử lý cho cùng đối tượng. */
    private Long pendingCountForTarget;
}
