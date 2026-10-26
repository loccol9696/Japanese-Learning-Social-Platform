package com.jlsp.backend.report.service.impl;

import com.jlsp.backend.common.exception.AppException;
import com.jlsp.backend.common.exception.ResourceNotFoundException;
import com.jlsp.backend.common.response.PageResponse;
import com.jlsp.backend.common.security.token.RefreshTokenService;
import com.jlsp.backend.report.dto.CreateReportRequest;
import com.jlsp.backend.report.dto.ReportResponse;
import com.jlsp.backend.report.dto.ResolveReportRequest;
import com.jlsp.backend.report.entity.Report;
import com.jlsp.backend.report.entity.ReportAction;
import com.jlsp.backend.report.entity.ReportReason;
import com.jlsp.backend.report.entity.ReportStatus;
import com.jlsp.backend.report.entity.ReportTargetType;
import com.jlsp.backend.report.repository.ReportRepository;
import com.jlsp.backend.report.service.ReportService;
import com.jlsp.backend.user.entity.User;
import com.jlsp.backend.user.entity.UserRole;
import com.jlsp.backend.user.repository.UserRepository;
import com.jlsp.backend.video.entity.Video;
import com.jlsp.backend.video.entity.VideoComment;
import com.jlsp.backend.video.entity.VideoModStatus;
import com.jlsp.backend.video.entity.VideoStatus;
import com.jlsp.backend.video.repository.VideoCommentRepository;
import com.jlsp.backend.video.repository.VideoRepository;
import com.jlsp.backend.video.service.CommentService;
import com.jlsp.backend.video.service.VideoService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;

@Service
@RequiredArgsConstructor
@Slf4j
@Transactional(readOnly = true)
public class ReportServiceImpl implements ReportService {

    private static final int SUMMARY_MAX = 80;

    private final ReportRepository reportRepository;
    private final UserRepository userRepository;
    private final VideoRepository videoRepository;
    private final VideoCommentRepository commentRepository;
    private final VideoService videoService;
    private final CommentService commentService;
    private final RefreshTokenService refreshTokenService;
    private final com.jlsp.backend.notification.service.NotificationService notificationService;

    /** Chủ nội dung bị báo cáo, null nếu đối tượng không còn tồn tại. */
    private record Target(boolean exists, Long ownerId, String ownerUsername, String summary, Long videoId) {
        static final Target MISSING = new Target(false, null, null, null, null);
    }

    @Override
    @Transactional
    public ReportResponse create(Long reporterId, CreateReportRequest request) {
        User reporter = userRepository.findById(reporterId)
                .orElseThrow(() -> new ResourceNotFoundException("User", "id", reporterId));

        Target target = resolveTarget(request.getTargetType(), request.getTargetId());
        if (!target.exists()) {
            throw new AppException(404, "Đối tượng báo cáo không còn tồn tại");
        }
        if (reporterId.equals(target.ownerId())) {
            throw new AppException(400, "Bạn không thể báo cáo nội dung của chính mình");
        }
        if (reportRepository.existsByReporterIdAndTargetTypeAndTargetIdAndStatus(
                reporterId, request.getTargetType(), request.getTargetId(), ReportStatus.PENDING)) {
            throw new AppException(409, "Bạn đã báo cáo nội dung này, báo cáo đang chờ xử lý");
        }

        String detail = request.getDetail() == null ? null : request.getDetail().trim();
        Report saved = reportRepository.save(Report.builder()
                .reporter(reporter)
                .targetType(request.getTargetType())
                .targetId(request.getTargetId())
                .reason(request.getReason())
                .detail(detail == null || detail.isEmpty() ? null : detail)
                .build());
        log.info("User {} báo cáo {} #{} với lý do {}", reporterId, saved.getTargetType(),
                saved.getTargetId(), saved.getReason());
        return toResponse(saved, target);
    }

    @Override
    public PageResponse<ReportResponse> list(ReportStatus status, ReportTargetType targetType, Pageable pageable) {
        ReportStatus effective = status != null ? status : ReportStatus.PENDING;
        Page<Report> page = targetType != null
                ? reportRepository.findByStatusAndTargetType(effective, targetType, pageable)
                : reportRepository.findByStatus(effective, pageable);
        return PageResponse.<ReportResponse>builder()
                .content(page.getContent().stream()
                        .map(r -> toResponse(r, resolveTarget(r.getTargetType(), r.getTargetId())))
                        .toList())
                .page(page.getNumber())
                .size(page.getSize())
                .totalElements(page.getTotalElements())
                .totalPages(page.getTotalPages())
                .last(page.isLast())
                .build();
    }

    @Override
    @Transactional
    public ReportResponse resolve(Long reportId, Long actorId, boolean actorIsAdmin, ResolveReportRequest request) {
        Report report = requirePending(reportId);
        Target target = resolveTarget(report.getTargetType(), report.getTargetId());
        ReportAction action = request.getAction();

        applyAction(report, target, action, actorId, actorIsAdmin, request.getNote());
        closeAllPendingFor(report, ReportStatus.RESOLVED, action, actorId, request.getNote());
        log.info("Actor {} xử lý báo cáo #{} ({} #{}) bằng hành động {}", actorId, reportId,
                report.getTargetType(), report.getTargetId(), action);
        return toResponse(report, resolveTarget(report.getTargetType(), report.getTargetId()));
    }

    @Override
    @Transactional
    public ReportResponse dismiss(Long reportId, Long actorId, String note) {
        Report report = requirePending(reportId);
        closeAllPendingFor(report, ReportStatus.DISMISSED, null, actorId, note);
        log.info("Actor {} bác bỏ báo cáo #{} ({} #{})", actorId, reportId,
                report.getTargetType(), report.getTargetId());
        return toResponse(report, resolveTarget(report.getTargetType(), report.getTargetId()));
    }

    // ---------------------------------------------------------------- helpers

    private Report requirePending(Long reportId) {
        Report report = reportRepository.findById(reportId)
                .orElseThrow(() -> new ResourceNotFoundException("Report", "id", reportId));
        if (report.getStatus() != ReportStatus.PENDING) {
            throw new AppException(400, "Báo cáo này đã được xử lý");
        }
        return report;
    }

    private void applyAction(Report report, Target target, ReportAction action,
                             Long actorId, boolean actorIsAdmin, String note) {
        switch (action) {
            case NONE -> { }
            case HIDE_VIDEO -> {
                if (report.getTargetType() != ReportTargetType.VIDEO) {
                    throw new AppException(400, "Chỉ có thể ẩn video với báo cáo về video");
                }
                Video video = videoRepository.findById(report.getTargetId()).orElse(null);
                // Video đã xóa / không còn công khai / đã bị từ chối thì không còn gì để ẩn.
                if (video != null && video.getStatus() == VideoStatus.PUBLIC
                        && video.getModStatus() != VideoModStatus.REJECTED) {
                    videoService.rejectVideo(video.getId(), actorId, rejectionMessage(report.getReason(), note));
                }
            }
            case DELETE_COMMENT -> {
                if (report.getTargetType() != ReportTargetType.COMMENT) {
                    throw new AppException(400, "Chỉ có thể xóa bình luận với báo cáo về bình luận");
                }
                if (target.exists()) {
                    commentService.delete(target.videoId(), report.getTargetId(), actorId, true);
                    notificationService.notify(target.ownerId(), null, com.jlsp.backend.notification.entity.NotificationType.CONTENT_REMOVED,
                            target.videoId(), null, "Bình luận của bạn đã bị xóa do vi phạm tiêu chuẩn cộng đồng.");
                }
            }
            case LOCK_USER -> {
                if (!actorIsAdmin) {
                    throw new AppException(403, "Chỉ Admin mới được khóa tài khoản");
                }
                if (!target.exists()) {
                    throw new AppException(400, "Đối tượng không còn tồn tại nên không thể khóa chủ tài khoản");
                }
                lockUser(target.ownerId());
            }
        }
    }

    private void lockUser(Long userId) {
        User owner = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("User", "id", userId));
        if (owner.getRole() != UserRole.USER) {
            throw new AppException(400, "Không thể khóa tài khoản quản trị / kiểm duyệt qua báo cáo");
        }
        owner.setIsActive(false);
        userRepository.save(owner);
        // Đăng xuất mọi thiết bị; access token còn lại tự hết hạn trong vài phút.
        refreshTokenService.revokeAll(owner.getId());
    }

    private void closeAllPendingFor(Report anchor, ReportStatus status, ReportAction action,
                                    Long actorId, String note) {
        String cleanNote = note == null || note.isBlank() ? null : note.trim();
        LocalDateTime now = LocalDateTime.now();
        List<Report> pending = reportRepository.findByTargetTypeAndTargetIdAndStatus(
                anchor.getTargetType(), anchor.getTargetId(), ReportStatus.PENDING);
        for (Report r : pending) {
            r.setStatus(status);
            r.setAction(action);
            r.setResolvedBy(actorId);
            r.setResolvedAt(now);
            r.setResolutionNote(cleanNote);
        }
        reportRepository.saveAll(pending);

        // Báo kết quả cho từng người đã báo cáo.
        String outcome = status == ReportStatus.RESOLVED
                ? "Báo cáo của bạn đã được xử lý. Cảm ơn bạn đã giúp cộng đồng an toàn hơn."
                : "Báo cáo của bạn đã được xem xét, chúng tôi không phát hiện vi phạm.";
        for (Report r : pending) {
            notificationService.notify(r.getReporter().getId(), null, com.jlsp.backend.notification.entity.NotificationType.REPORT_UPDATE,
                    r.getTargetType() == ReportTargetType.VIDEO ? r.getTargetId() : null, null, outcome);
        }
    }

    private Target resolveTarget(ReportTargetType type, Long id) {
        return switch (type) {
            case VIDEO -> videoRepository.findById(id)
                    .map(v -> new Target(true, v.getUser().getId(), v.getUser().getUsername(),
                            abbreviate(v.getTitle()), v.getId()))
                    .orElse(Target.MISSING);
            case COMMENT -> commentRepository.findById(id)
                    .map((VideoComment c) -> new Target(true, c.getUser().getId(), c.getUser().getUsername(),
                            abbreviate(c.getContent()), c.getVideo().getId()))
                    .orElse(Target.MISSING);
            case USER -> userRepository.findById(id)
                    .map(u -> new Target(true, u.getId(), u.getUsername(), u.getUsername(), null))
                    .orElse(Target.MISSING);
        };
    }

    private static String abbreviate(String text) {
        if (text == null) return null;
        String single = text.replaceAll("\\s+", " ").trim();
        return single.length() <= SUMMARY_MAX ? single : single.substring(0, SUMMARY_MAX - 1) + "…";
    }

    private static String rejectionMessage(ReportReason reason, String note) {
        String base = "Bị báo cáo: " + reasonLabel(reason);
        return note == null || note.isBlank() ? base : base + ". " + note.trim();
    }

    private static String reasonLabel(ReportReason reason) {
        return switch (reason) {
            case SPAM -> "spam hoặc quảng cáo";
            case INAPPROPRIATE -> "nội dung không phù hợp";
            case HARASSMENT -> "quấy rối hoặc thù ghét";
            case MISINFORMATION -> "thông tin sai lệch";
            case COPYRIGHT -> "vi phạm bản quyền";
            case OTHER -> "vi phạm tiêu chuẩn cộng đồng";
        };
    }

    private ReportResponse toResponse(Report r, Target target) {
        User reporter = r.getReporter();
        return ReportResponse.builder()
                .id(r.getId())
                .targetType(r.getTargetType())
                .targetId(r.getTargetId())
                .reason(r.getReason())
                .detail(r.getDetail())
                .status(r.getStatus())
                .action(r.getAction())
                .resolutionNote(r.getResolutionNote())
                .resolvedBy(r.getResolvedBy())
                .resolvedAt(r.getResolvedAt())
                .createdAt(r.getCreatedAt())
                .reporterId(reporter.getId())
                .reporterUsername(reporter.getUsername())
                .targetExists(target.exists())
                .targetSummary(target.summary())
                .targetOwnerId(target.ownerId())
                .targetOwnerUsername(target.ownerUsername())
                .targetVideoId(target.videoId())
                .pendingCountForTarget(reportRepository.countByTargetTypeAndTargetIdAndStatus(
                        r.getTargetType(), r.getTargetId(), ReportStatus.PENDING))
                .build();
    }
}
