package com.jlsp.backend.report.service.impl;

import com.jlsp.backend.chat.entity.Message;
import com.jlsp.backend.chat.repository.MessageRepository;
import com.jlsp.backend.chat.service.ChatService;
import com.jlsp.backend.common.exception.AppException;
import com.jlsp.backend.common.exception.ResourceNotFoundException;
import com.jlsp.backend.common.response.PageResponse;
import com.jlsp.backend.common.security.ratelimit.RateLimiter;
import com.jlsp.backend.common.security.token.RefreshTokenService;
import com.jlsp.backend.notification.entity.NotificationType;
import com.jlsp.backend.report.dto.CreateReportRequest;
import com.jlsp.backend.report.dto.ReportCorrection;
import com.jlsp.backend.report.dto.ReportResponse;
import com.jlsp.backend.report.dto.ReportResultResponse;
import com.jlsp.backend.report.dto.ResolveReportRequest;
import com.jlsp.backend.report.entity.Report;
import com.jlsp.backend.report.entity.ReportAction;
import com.jlsp.backend.report.entity.ReportReason;
import com.jlsp.backend.report.entity.ReportStatus;
import com.jlsp.backend.report.entity.ReportTargetType;
import com.jlsp.backend.report.event.AccountLockedEvent;
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
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Objects;

@Service
@RequiredArgsConstructor
@Slf4j
@Transactional(readOnly = true)
public class ReportServiceImpl implements ReportService {

    private static final int SUMMARY_MAX = 80;
    /** Mỗi người gửi tối đa chừng này báo cáo mỗi giờ, tránh spam hàng đợi của kiểm duyệt viên. */
    static final int MAX_REPORTS_PER_HOUR = 20;

    private final ReportRepository reportRepository;
    private final UserRepository userRepository;
    private final VideoRepository videoRepository;
    private final VideoCommentRepository commentRepository;
    private final MessageRepository messageRepository;
    private final VideoService videoService;
    private final CommentService commentService;
    private final ChatService chatService;
    private final RefreshTokenService refreshTokenService;
    private final com.jlsp.backend.notification.service.NotificationService notificationService;
    private final RateLimiter rateLimiter;
    private final ApplicationEventPublisher eventPublisher;

    /**
     * Đối tượng bị báo cáo. exists = false nghĩa là nội dung đã mất; ownerId vẫn có khi còn biết chủ
     * (tin đã thu hồi, câu đã bị sửa), để người vi phạm không tránh được việc khóa tài khoản bằng cách xóa.
     */
    private record Target(boolean exists, Long ownerId, String ownerUsername, String summary, Long videoId,
                          String snapshot, String imageUrl, String videoUrl, ReportCorrection content) {
        static final Target MISSING = new Target(false, null, null, null, null, null, null, null);

        Target(boolean exists, Long ownerId, String ownerUsername, String summary, Long videoId,
               String snapshot, String imageUrl, String videoUrl) {
            this(exists, ownerId, ownerUsername, summary, videoId, snapshot, imageUrl, videoUrl, null);
        }

        static Target gone(User owner, Long videoId, String videoUrl) {
            return new Target(false, owner.getId(), owner.getUsername(), null, videoId, null, null, videoUrl);
        }
    }

    @Override
    @Transactional
    public ReportResponse create(Long reporterId, CreateReportRequest request) {
        User reporter = userRepository.findById(reporterId)
                .orElseThrow(() -> new ResourceNotFoundException("User", "id", reporterId));

        String targetKey = targetKeyOf(request);
        Target target = resolveTarget(request.getTargetType(), request.getTargetId(), targetKey);
        if (!target.exists() || !canSee(reporterId, request.getTargetType(), request.getTargetId())) {
            throw new AppException(404, "Đối tượng báo cáo không còn tồn tại");
        }
        if (reporterId.equals(target.ownerId())) {
            throw new AppException(400, "Bạn không thể báo cáo nội dung của chính mình");
        }
        if (reportRepository.existsByReporterIdAndTargetTypeAndTargetIdAndTargetKeyAndStatus(
                reporterId, request.getTargetType(), request.getTargetId(), targetKey, ReportStatus.PENDING)) {
            throw new AppException(409, "Bạn đã báo cáo nội dung này, báo cáo đang chờ xử lý");
        }
        // Đặt sau các kiểm tra hợp lệ để báo cáo bị từ chối không tốn lượt.
        RateLimiter.Decision decision = rateLimiter.tryAcquire(
                "report:" + reporterId, MAX_REPORTS_PER_HOUR, Duration.ofHours(1));
        if (!decision.allowed()) {
            throw new AppException(429, "Bạn gửi báo cáo quá nhanh. Vui lòng thử lại sau "
                    + (decision.retryAfterSeconds() / 60 + 1) + " phút");
        }

        String detail = request.getDetail() == null ? null : request.getDetail().trim();
        Report saved = reportRepository.save(Report.builder()
                .reporter(reporter)
                .targetType(request.getTargetType())
                .targetId(request.getTargetId())
                .targetKey(targetKey)
                .targetSnapshot(target.snapshot())
                .snapshotImageUrl(target.imageUrl())
                .reason(request.getReason())
                .detail(detail == null || detail.isEmpty() ? null : detail)
                .build());
        log.info("User {} báo cáo {} #{} với lý do {}", reporterId, saved.getTargetType(),
                saved.getTargetId(), saved.getReason());
        ReportResponse response = toResponse(saved, target);
        // Số lần vi phạm của người khác chỉ dành cho kiểm duyệt viên.
        response.setTargetOwnerViolationCount(null);
        return response;
    }

    @Override
    public PageResponse<ReportResponse> list(ReportStatus status, ReportTargetType targetType, Pageable pageable) {
        ReportStatus effective = status != null ? status : ReportStatus.PENDING;
        Page<Report> page = targetType != null
                ? reportRepository.findByStatusAndTargetType(effective, targetType, pageable)
                : reportRepository.findByStatus(effective, pageable);
        return PageResponse.<ReportResponse>builder()
                .content(page.getContent().stream()
                        .map(r -> toResponse(r, resolveTarget(r)))
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
        Target target = resolveTarget(report);
        ReportAction action = request.getAction();

        applyAction(report, target, action, actorId, actorIsAdmin, request.getNote(), request.getCorrection());
        closeAllPendingFor(report, ReportStatus.RESOLVED, action, actorId, request.getNote());
        log.info("Actor {} xử lý báo cáo #{} ({} #{}) bằng hành động {}", actorId, reportId,
                report.getTargetType(), report.getTargetId(), action);
        return toResponse(report, resolveTarget(report));
    }

    @Override
    @Transactional
    public ReportResponse dismiss(Long reportId, Long actorId, String note) {
        Report report = requirePending(reportId);
        closeAllPendingFor(report, ReportStatus.DISMISSED, null, actorId, note);
        log.info("Actor {} bác bỏ báo cáo #{} ({} #{})", actorId, reportId,
                report.getTargetType(), report.getTargetId());
        return toResponse(report, resolveTarget(report));
    }

    @Override
    public ReportResultResponse getResult(Long userId, Long reportId) {
        Report report = reportRepository.findById(reportId)
                .orElseThrow(() -> new ResourceNotFoundException("Report", "id", reportId));
        boolean isReporter = userId.equals(report.getReporter().getId());
        if (!isReporter && !notificationService.wasNotifiedAboutReport(userId, reportId)) {
            throw new ResourceNotFoundException("Report", "id", reportId);
        }
        boolean dismissed = report.getStatus() == ReportStatus.DISMISSED;
        String snapshot = report.getTargetSnapshot();
        return ReportResultResponse.builder()
                .id(report.getId())
                .targetType(report.getTargetType())
                .content(snapshot != null ? snapshot : resolveTarget(report).summary())
                .reason(report.getReason())
                // Mô tả có thể làm lộ người báo cáo nên không đưa cho chủ nội dung.
                .detail(isReporter ? report.getDetail() : null)
                .status(report.getStatus())
                .outcome(outcomeLabel(report, isReporter))
                // Ghi chú khi xử lý viết cho chủ nội dung, khi bác bỏ viết cho người báo cáo.
                .note(isReporter == dismissed ? report.getResolutionNote() : null)
                .createdAt(report.getCreatedAt())
                .resolvedAt(report.getResolvedAt())
                .build();
    }

    // ---------------------------------------------------------------- helpers

    private static String outcomeLabel(Report report, boolean isReporter) {
        if (report.getStatus() == ReportStatus.PENDING) {
            return "Báo cáo đang chờ xử lý";
        }
        if (report.getStatus() == ReportStatus.DISMISSED) {
            return "Không phát hiện vi phạm";
        }
        return switch (report.getAction()) {
            case WARN_USER -> isReporter ? "Đã nhắc nhở chủ nội dung" : "Bạn đã bị nhắc nhở";
            case HIDE_VIDEO -> "Đã ẩn video";
            case DELETE_COMMENT -> "Đã xóa bình luận";
            case HIDE_MESSAGE -> "Đã gỡ tin nhắn";
            case EDIT_TRANSLATION -> "Đã sửa lại bản dịch";
            case REMOVE_TRANSLATION -> "Đã gỡ bản dịch";
            case EDIT_GRAMMAR -> "Đã sửa lại mẫu ngữ pháp";
            case REMOVE_GRAMMAR -> "Đã gỡ mẫu ngữ pháp";
            case LOCK_USER -> "Đã khóa tài khoản vi phạm";
            case NONE -> "Báo cáo đã được xử lý";
        };
    }

    private static String targetKeyOf(CreateReportRequest request) {
        ReportTargetType type = request.getTargetType();
        if (type != ReportTargetType.TRANSLATION && type != ReportTargetType.GRAMMAR) {
            return "";
        }
        Integer index = request.getSegmentIndex();
        if (index == null) {
            throw new AppException(400, "Thiếu vị trí câu phụ đề");
        }
        if (type == ReportTargetType.TRANSLATION) {
            return index.toString();
        }
        String pattern = request.getGrammarPattern();
        if (pattern == null || pattern.isBlank()) {
            throw new AppException(400, "Thiếu mẫu ngữ pháp");
        }
        return index + ":" + pattern;
    }

    /**
     * Bản dịch và tin nhắn không công khai như video nên phải chặn người không xem được, nếu không có
     * thể dò nội dung bằng cách gửi báo cáo. Trả về như đối tượng không tồn tại để không lộ gì thêm.
     */
    private boolean canSee(Long reporterId, ReportTargetType type, Long targetId) {
        return switch (type) {
            case MESSAGE -> messageRepository.findById(targetId)
                    .map(m -> isParticipant(m, reporterId))
                    .orElse(false);
            case TRANSLATION, GRAMMAR -> videoRepository.findById(targetId)
                    .map(v -> v.getStatus() != VideoStatus.PRIVATE && v.getStatus() != VideoStatus.DRAFT)
                    .orElse(false);
            default -> true;
        };
    }

    private static boolean isParticipant(Message message, Long userId) {
        return userId.equals(message.getConversation().getUserLow().getId())
                || userId.equals(message.getConversation().getUserHigh().getId());
    }

    private Report requirePending(Long reportId) {
        Report report = reportRepository.findById(reportId)
                .orElseThrow(() -> new ResourceNotFoundException("Report", "id", reportId));
        if (report.getStatus() != ReportStatus.PENDING) {
            throw new AppException(400, "Báo cáo này đã được xử lý");
        }
        return report;
    }

    private void applyAction(Report report, Target target, ReportAction action, Long actorId,
                             boolean actorIsAdmin, String note, ReportCorrection correction) {
        switch (action) {
            case NONE -> { }
            case WARN_USER -> {
                if (target.ownerId() == null) {
                    throw new AppException(400, "Không còn biết chủ nội dung nên không thể nhắc nhở");
                }
                userRepository.incrementViolationCount(target.ownerId());
                notifyOwner(NotificationType.VIOLATION_WARNING, target, report,
                        warningSubject(report.getTargetType()), note);
            }
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
                    notifyOwner(NotificationType.CONTENT_REMOVED, target, report, "Bình luận của bạn đã bị xóa", note);
                }
            }
            case HIDE_MESSAGE -> {
                if (report.getTargetType() != ReportTargetType.MESSAGE) {
                    throw new AppException(400, "Chỉ có thể gỡ tin nhắn với báo cáo về tin nhắn");
                }
                // Tin đã bị người gửi thu hồi thì không còn gì để gỡ.
                if (target.exists()) {
                    chatService.removeMessageByModeration(report.getTargetId());
                    notifyOwner(NotificationType.CONTENT_REMOVED, target, report, "Tin nhắn của bạn đã bị gỡ", note);
                }
            }
            case REMOVE_TRANSLATION -> {
                if (report.getTargetType() != ReportTargetType.TRANSLATION) {
                    throw new AppException(400, "Chỉ có thể gỡ bản dịch với báo cáo về bản dịch");
                }
                // Chủ video đã sửa câu này sau khi bị báo cáo thì giữ nguyên, tránh gỡ nhầm nội dung mới.
                if (matchesReportedContent(report, target)) {
                    Video video = videoRepository.findById(report.getTargetId()).orElseThrow();
                    video.setSubtitles(SubtitleLines.withoutTranslation(video.getSubtitles(),
                            lineIndexOf(report.getTargetKey())));
                    videoRepository.save(video);
                    notifyOwner(NotificationType.CONTENT_REMOVED, target, report,
                            "Một bản dịch trong video của bạn đã bị gỡ", note);
                }
            }
            case EDIT_TRANSLATION -> {
                requireEditable(report, target, ReportTargetType.TRANSLATION);
                String translation = requireText(correction == null ? null : correction.getTranslation(),
                        "Vui lòng nhập bản dịch đã sửa");
                Video video = videoRepository.findById(report.getTargetId()).orElseThrow();
                video.setSubtitles(SubtitleLines.withTranslation(video.getSubtitles(),
                        lineIndexOf(report.getTargetKey()), translation));
                videoRepository.save(video);
                notifyOwner(NotificationType.CONTENT_EDITED, target, report,
                        "Một bản dịch trong video của bạn đã được sửa lại", note);
            }
            case EDIT_GRAMMAR -> {
                requireEditable(report, target, ReportTargetType.GRAMMAR);
                ReportCorrection fix = correction != null ? correction : new ReportCorrection();
                SubtitleLines.Grammar corrected = new SubtitleLines.Grammar(
                        requireText(fix.getPattern(), "Vui lòng nhập mẫu ngữ pháp"), null,
                        requireText(fix.getMeaning(), "Vui lòng nhập ý nghĩa của mẫu ngữ pháp"),
                        fix.getExplanation() == null ? "" : fix.getExplanation().trim());
                Video video = videoRepository.findById(report.getTargetId()).orElseThrow();
                SubtitleLines.GrammarEdit edit = SubtitleLines.withGrammar(video.getSubtitles(),
                        video.getGrammarAnalysis(), lineIndexOf(report.getTargetKey()),
                        patternOf(report.getTargetKey()), corrected);
                video.setSubtitles(edit.subtitles());
                video.setGrammarAnalysis(edit.grammarAnalysis());
                videoRepository.save(video);
                notifyOwner(NotificationType.CONTENT_EDITED, target, report,
                        "Một mẫu ngữ pháp trong video của bạn đã được sửa lại", note);
            }
            case REMOVE_GRAMMAR -> {
                if (report.getTargetType() != ReportTargetType.GRAMMAR) {
                    throw new AppException(400, "Chỉ có thể gỡ ngữ pháp với báo cáo về ngữ pháp");
                }
                if (matchesReportedContent(report, target)) {
                    Video video = videoRepository.findById(report.getTargetId()).orElseThrow();
                    SubtitleLines.GrammarEdit edit = SubtitleLines.withoutGrammar(video.getSubtitles(),
                            video.getGrammarAnalysis(), lineIndexOf(report.getTargetKey()),
                            patternOf(report.getTargetKey()));
                    video.setSubtitles(edit.subtitles());
                    video.setGrammarAnalysis(edit.grammarAnalysis());
                    videoRepository.save(video);
                    notifyOwner(NotificationType.CONTENT_REMOVED, target, report,
                            "Một mẫu ngữ pháp trong video của bạn đã bị gỡ", note);
                }
            }
            case LOCK_USER -> {
                if (!actorIsAdmin) {
                    throw new AppException(403, "Chỉ Admin mới được khóa tài khoản");
                }
                if (target.ownerId() == null) {
                    throw new AppException(400, "Đối tượng không còn tồn tại nên không thể khóa chủ tài khoản");
                }
                lockUser(target.ownerId(), report.getReason(), note);
            }
        }
    }

    private static String warningSubject(ReportTargetType type) {
        String content = switch (type) {
            case VIDEO -> "Video của bạn";
            case COMMENT -> "Bình luận của bạn";
            case USER -> "Tài khoản của bạn";
            case MESSAGE -> "Tin nhắn của bạn";
            case TRANSLATION -> "Bản dịch trong video của bạn";
            case GRAMMAR -> "Phần ngữ pháp trong video của bạn";
        };
        return content + " đã vi phạm tiêu chuẩn cộng đồng";
    }

    /** Báo chủ nội dung biết nội dung đã bị gỡ hay sửa và lý do; người báo cáo vẫn được ẩn danh. */
    private void notifyOwner(NotificationType type, Target target, Report report, String subject, String note) {
        notificationService.notifyReportResult(target.ownerId(), type, target.videoId(), report.getId(),
                withNote(subject + ". Lý do: " + reasonLabel(report.getReason()), note));
    }

    private static boolean matchesReportedContent(Report report, Target target) {
        return target.exists() && Objects.equals(report.getTargetSnapshot(), target.snapshot());
    }

    /** Khác với gỡ, sửa không thể bỏ qua âm thầm vì kiểm duyệt viên đang gửi lên một nội dung cụ thể. */
    private static void requireEditable(Report report, Target target, ReportTargetType type) {
        if (report.getTargetType() != type) {
            throw new AppException(400, "Hành động sửa không khớp với loại báo cáo");
        }
        if (!matchesReportedContent(report, target)) {
            throw new AppException(409, "Nội dung đã thay đổi sau khi bị báo cáo nên không thể sửa");
        }
    }

    private static String requireText(String value, String message) {
        if (value == null || value.isBlank()) {
            throw new AppException(400, message);
        }
        return value.trim();
    }

    private void lockUser(Long userId, ReportReason reason, String note) {
        User owner = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("User", "id", userId));
        if (owner.getRole() != UserRole.USER) {
            throw new AppException(400, "Không thể khóa tài khoản quản trị / kiểm duyệt qua báo cáo");
        }
        // Đã khóa từ báo cáo khác thì không gửi mail lần nữa.
        if (owner.getLockedAt() == null) {
            String name = owner.getDisplayName() == null || owner.getDisplayName().isBlank()
                    ? owner.getUsername() : owner.getDisplayName();
            eventPublisher.publishEvent(new AccountLockedEvent(owner.getEmail(), name,
                    withNote(reasonLabel(reason), note)));
        }
        owner.setIsActive(false);
        owner.setLockedAt(LocalDateTime.now());
        userRepository.save(owner);
        // Đăng xuất mọi thiết bị; access token còn lại tự hết hạn trong vài phút.
        refreshTokenService.revokeAll(owner.getId());
    }

    private void closeAllPendingFor(Report anchor, ReportStatus status, ReportAction action,
                                    Long actorId, String note) {
        String cleanNote = note == null || note.isBlank() ? null : note.trim();
        LocalDateTime now = LocalDateTime.now();
        List<Report> pending = reportRepository.findByTargetTypeAndTargetIdAndTargetKeyAndStatus(
                anchor.getTargetType(), anchor.getTargetId(), anchor.getTargetKey(), ReportStatus.PENDING);
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
            notificationService.notifyReportResult(r.getReporter().getId(), NotificationType.REPORT_UPDATE,
                    reportedVideoIdOf(r), r.getId(), outcome);
        }
    }

    /** Video để người báo cáo mở lại từ thông báo. */
    private static Long reportedVideoIdOf(Report report) {
        return switch (report.getTargetType()) {
            case VIDEO, TRANSLATION, GRAMMAR -> report.getTargetId();
            default -> null;
        };
    }

    private Target resolveTarget(Report report) {
        return resolveTarget(report.getTargetType(), report.getTargetId(), report.getTargetKey());
    }

    private Target resolveTarget(ReportTargetType type, Long id, String key) {
        return switch (type) {
            case VIDEO -> videoRepository.findById(id)
                    .map(v -> new Target(true, v.getUser().getId(), v.getUser().getUsername(),
                            abbreviate(v.getTitle()), v.getId(), null, null, v.getVideoUrl()))
                    .orElse(Target.MISSING);
            case COMMENT -> commentRepository.findById(id)
                    .map((VideoComment c) -> new Target(true, c.getUser().getId(), c.getUser().getUsername(),
                            abbreviate(c.getContent()), c.getVideo().getId(), c.getContent(), null, null))
                    .orElse(Target.MISSING);
            case USER -> userRepository.findById(id)
                    .map(u -> new Target(true, u.getId(), u.getUsername(), u.getUsername(), null, null, null, null))
                    .orElse(Target.MISSING);
            case MESSAGE -> messageRepository.findById(id)
                    .map(ReportServiceImpl::messageTarget)
                    .orElse(Target.MISSING);
            case TRANSLATION -> videoRepository.findById(id)
                    .map(v -> translationTarget(v, lineIndexOf(key)))
                    .orElse(Target.MISSING);
            case GRAMMAR -> videoRepository.findById(id)
                    .map(v -> grammarTarget(v, lineIndexOf(key), patternOf(key)))
                    .orElse(Target.MISSING);
        };
    }

    private static Target messageTarget(Message message) {
        User sender = message.getSender();
        if (message.getRecalledAt() != null) {
            return Target.gone(sender, null, null);
        }
        String text = messageText(message);
        return new Target(true, sender.getId(), sender.getUsername(), abbreviate(text), null, text,
                message.getImageUrl(), null);
    }

    private static String messageText(Message message) {
        String content = message.getContent() == null ? "" : message.getContent();
        String prefix = switch (message.getType()) {
            case TEXT -> "";
            case IMAGE -> "[Ảnh] ";
            case VIDEO_SHARE -> "[Chia sẻ video #" + message.getVideoId() + "] ";
            case DECK_SHARE -> "[Chia sẻ bộ thẻ #" + message.getDeckId() + "] ";
        };
        return (prefix + content).trim();
    }

    private static Target translationTarget(Video video, int index) {
        return SubtitleLines.find(video.getSubtitles(), index)
                .filter(line -> !line.translation().isBlank())
                .map(line -> videoLineTarget(video, abbreviate(line.translation()),
                        "Câu: " + line.text() + "\nBản dịch: " + line.translation(),
                        ReportCorrection.builder().translation(line.translation()).build()))
                .orElseGet(() -> Target.gone(video.getUser(), video.getId(), video.getVideoUrl()));
    }

    private static Target grammarTarget(Video video, int index, String pattern) {
        String sentence = SubtitleLines.find(video.getSubtitles(), index).map(SubtitleLines.Line::text).orElse("");
        return SubtitleLines.findGrammar(video.getSubtitles(), video.getGrammarAnalysis(), index, pattern)
                .map(g -> videoLineTarget(video, abbreviate(pattern + " – " + g.meaning()),
                        "Câu: " + sentence + "\nMẫu: " + pattern + "\nKhớp trong câu: " + g.matchedText()
                                + "\nNghĩa: " + g.meaning() + "\nGiải thích: " + g.explanation(),
                        ReportCorrection.builder().pattern(pattern).meaning(g.meaning())
                                .explanation(g.explanation()).build()))
                .orElseGet(() -> Target.gone(video.getUser(), video.getId(), video.getVideoUrl()));
    }

    private static Target videoLineTarget(Video video, String summary, String snapshot, ReportCorrection content) {
        return new Target(true, video.getUser().getId(), video.getUser().getUsername(), summary, video.getId(),
                snapshot, null, video.getVideoUrl(), content);
    }

    /** Vị trí câu trong khóa "12" hoặc "12:〜ている". */
    private static int lineIndexOf(String key) {
        int colon = key.indexOf(':');
        return Integer.parseInt(colon < 0 ? key : key.substring(0, colon));
    }

    private static String patternOf(String key) {
        return key.substring(key.indexOf(':') + 1);
    }

    private static String abbreviate(String text) {
        if (text == null) return null;
        String single = text.replaceAll("\\s+", " ").trim();
        return single.length() <= SUMMARY_MAX ? single : single.substring(0, SUMMARY_MAX - 1) + "…";
    }

    private static String rejectionMessage(ReportReason reason, String note) {
        return withNote("Bị báo cáo: " + reasonLabel(reason), note);
    }

    private static String withNote(String base, String note) {
        return note == null || note.isBlank() ? base : base + ". " + note.trim();
    }

    private static String reasonLabel(ReportReason reason) {
        return switch (reason) {
            case SPAM -> "spam hoặc quảng cáo";
            case INAPPROPRIATE -> "nội dung không phù hợp";
            case HARASSMENT -> "quấy rối hoặc thù ghét";
            case MISINFORMATION -> "thông tin sai lệch";
            case COPYRIGHT -> "vi phạm bản quyền";
            case INACCURATE -> "dịch hoặc giải thích sai";
            case OTHER -> "vi phạm tiêu chuẩn cộng đồng";
        };
    }

    private static boolean isVideoLine(ReportTargetType type) {
        return type == ReportTargetType.TRANSLATION || type == ReportTargetType.GRAMMAR;
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
                .targetExists(isVideoLine(r.getTargetType()) ? matchesReportedContent(r, target) : target.exists())
                .targetSummary(target.summary())
                // Ưu tiên bản lưu lúc báo cáo; báo cáo cũ chưa có thì lấy nội dung hiện tại.
                .targetSnapshot(r.getTargetSnapshot() != null ? r.getTargetSnapshot() : target.snapshot())
                .targetImageUrl(r.getSnapshotImageUrl())
                .targetContent(target.content())
                .targetOwnerId(target.ownerId())
                .targetOwnerUsername(target.ownerUsername())
                .targetOwnerViolationCount(target.ownerId() == null ? null
                        : userRepository.findById(target.ownerId()).map(User::getViolationCount).orElse(null))
                .targetVideoId(target.videoId())
                .targetVideoUrl(target.videoUrl())
                .pendingCountForTarget(reportRepository.countByTargetTypeAndTargetIdAndTargetKeyAndStatus(
                        r.getTargetType(), r.getTargetId(), r.getTargetKey(), ReportStatus.PENDING))
                .build();
    }
}
