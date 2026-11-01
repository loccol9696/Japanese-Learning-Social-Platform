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
    /** Tiêu đề video / nội dung (rút gọn) / username. */
    private String targetSummary;
    /** Nguyên văn nội dung lúc báo cáo, để kiểm duyệt viên xem đầy đủ. */
    private String targetSnapshot;
    /** Ảnh của tin nhắn bị báo cáo. */
    private String targetImageUrl;
    /** Bản dịch / mẫu ngữ pháp hiện tại, để điền sẵn vào form sửa. */
    private ReportCorrection targetContent;
    /** Chủ nội dung bị báo cáo. */
    private Long targetOwnerId;
    private String targetOwnerUsername;
    /** Số lần chủ nội dung đã bị nhắc nhở, để cân nhắc có khóa tài khoản không. */
    private Integer targetOwnerViolationCount;
    /** Với bình luận, bản dịch, ngữ pháp: video chứa nội dung đó. */
    private Long targetVideoId;
    /** Link video để kiểm duyệt viên xem lại. */
    private String targetVideoUrl;
    /** Số báo cáo đang chờ xử lý cho cùng đối tượng. */
    private Long pendingCountForTarget;
}
