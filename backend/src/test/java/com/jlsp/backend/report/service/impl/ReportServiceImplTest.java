package com.jlsp.backend.report.service.impl;

import com.jlsp.backend.common.exception.AppException;
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
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class ReportServiceImplTest {

    private static final long REPORTER = 1L;
    private static final long OWNER = 2L;
    private static final long ACTOR = 9L;
    private static final long VIDEO_ID = 50L;
    private static final long COMMENT_ID = 70L;

    private ReportRepository reportRepository;
    private UserRepository userRepository;
    private VideoRepository videoRepository;
    private VideoCommentRepository commentRepository;
    private VideoService videoService;
    private CommentService commentService;
    private RefreshTokenService refreshTokenService;
    private ReportServiceImpl service;

    private User reporter;
    private User owner;
    private Video video;

    @BeforeEach
    void setUp() {
        reportRepository = mock(ReportRepository.class);
        userRepository = mock(UserRepository.class);
        videoRepository = mock(VideoRepository.class);
        commentRepository = mock(VideoCommentRepository.class);
        videoService = mock(VideoService.class);
        commentService = mock(CommentService.class);
        refreshTokenService = mock(RefreshTokenService.class);
        service = new ReportServiceImpl(reportRepository, userRepository, videoRepository, commentRepository,
                videoService, commentService, refreshTokenService,
                mock(com.jlsp.backend.notification.service.NotificationService.class));

        reporter = User.builder().id(REPORTER).username("reporter").build();
        owner = User.builder().id(OWNER).username("owner").role(UserRole.USER).isActive(true).build();
        video = Video.builder().id(VIDEO_ID).user(owner).title("Video vi phạm")
                .status(VideoStatus.PUBLIC).modStatus(VideoModStatus.APPROVED).build();

        when(userRepository.findById(REPORTER)).thenReturn(Optional.of(reporter));
        when(userRepository.findById(OWNER)).thenReturn(Optional.of(owner));
        when(videoRepository.findById(VIDEO_ID)).thenReturn(Optional.of(video));
        when(reportRepository.save(any(Report.class))).thenAnswer(inv -> inv.getArgument(0));
    }

    private static CreateReportRequest request(ReportTargetType type, long id) {
        return new CreateReportRequest(type, id, ReportReason.SPAM, " quảng cáo ");
    }

    private Report pending(ReportTargetType type, long targetId) {
        return Report.builder().id(5L).reporter(reporter).targetType(type).targetId(targetId)
                .reason(ReportReason.SPAM).build();
    }

    // ---- create

    @Test
    void createStoresTrimmedDetailAndReturnsTargetSummary() {
        ReportResponse response = service.create(REPORTER, request(ReportTargetType.VIDEO, VIDEO_ID));

        assertThat(response.getDetail()).isEqualTo("quảng cáo");
        assertThat(response.getStatus()).isEqualTo(ReportStatus.PENDING);
        assertThat(response.getTargetSummary()).isEqualTo("Video vi phạm");
        assertThat(response.getTargetOwnerUsername()).isEqualTo("owner");
    }

    @Test
    void cannotReportYourOwnContent() {
        assertThatThrownBy(() -> service.create(OWNER, request(ReportTargetType.VIDEO, VIDEO_ID)))
                .isInstanceOfSatisfying(AppException.class, e -> assertThat(e.getStatus()).isEqualTo(400));
        verify(reportRepository, never()).save(any());
    }

    @Test
    void cannotReportAMissingTarget() {
        when(videoRepository.findById(999L)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.create(REPORTER, request(ReportTargetType.VIDEO, 999L)))
                .isInstanceOfSatisfying(AppException.class, e -> assertThat(e.getStatus()).isEqualTo(404));
    }

    @Test
    void cannotSendASecondPendingReportForTheSameTarget() {
        when(reportRepository.existsByReporterIdAndTargetTypeAndTargetIdAndStatus(
                REPORTER, ReportTargetType.VIDEO, VIDEO_ID, ReportStatus.PENDING)).thenReturn(true);

        assertThatThrownBy(() -> service.create(REPORTER, request(ReportTargetType.VIDEO, VIDEO_ID)))
                .isInstanceOfSatisfying(AppException.class, e -> assertThat(e.getStatus()).isEqualTo(409));
        verify(reportRepository, never()).save(any());
    }

    // ---- resolve / dismiss

    @Test
    void resolveClosesEveryPendingReportOfTheSameTarget() {
        Report first = pending(ReportTargetType.VIDEO, VIDEO_ID);
        Report second = pending(ReportTargetType.VIDEO, VIDEO_ID);
        when(reportRepository.findById(5L)).thenReturn(Optional.of(first));
        when(reportRepository.findByTargetTypeAndTargetIdAndStatus(
                ReportTargetType.VIDEO, VIDEO_ID, ReportStatus.PENDING)).thenReturn(List.of(first, second));

        service.resolve(5L, ACTOR, false, new ResolveReportRequest(ReportAction.HIDE_VIDEO, "ok"));

        verify(videoService).rejectVideo(eq(VIDEO_ID), eq(ACTOR), anyString());
        assertThat(List.of(first, second)).allSatisfy(r -> {
            assertThat(r.getStatus()).isEqualTo(ReportStatus.RESOLVED);
            assertThat(r.getAction()).isEqualTo(ReportAction.HIDE_VIDEO);
            assertThat(r.getResolvedBy()).isEqualTo(ACTOR);
        });
    }

    @Test
    void hidingAnAlreadyRejectedVideoDoesNotRejectItAgain() {
        video.setModStatus(VideoModStatus.REJECTED);
        Report report = pending(ReportTargetType.VIDEO, VIDEO_ID);
        when(reportRepository.findById(5L)).thenReturn(Optional.of(report));
        when(reportRepository.findByTargetTypeAndTargetIdAndStatus(any(), anyLong(), any()))
                .thenReturn(List.of(report));

        service.resolve(5L, ACTOR, false, new ResolveReportRequest(ReportAction.HIDE_VIDEO, null));

        verify(videoService, never()).rejectVideo(anyLong(), anyLong(), any());
        assertThat(report.getStatus()).isEqualTo(ReportStatus.RESOLVED);
    }

    @Test
    void actionMustMatchTheTargetType() {
        Report report = pending(ReportTargetType.USER, OWNER);
        when(reportRepository.findById(5L)).thenReturn(Optional.of(report));

        assertThatThrownBy(() -> service.resolve(5L, ACTOR, true,
                new ResolveReportRequest(ReportAction.HIDE_VIDEO, null)))
                .isInstanceOfSatisfying(AppException.class, e -> assertThat(e.getStatus()).isEqualTo(400));
        assertThat(report.getStatus()).isEqualTo(ReportStatus.PENDING);
    }

    @Test
    void deleteCommentUsesTheVideoOfTheComment() {
        VideoComment comment = VideoComment.builder().id(COMMENT_ID).video(video).user(owner)
                .content("bình luận xấu").build();
        when(commentRepository.findById(COMMENT_ID)).thenReturn(Optional.of(comment));
        Report report = pending(ReportTargetType.COMMENT, COMMENT_ID);
        when(reportRepository.findById(5L)).thenReturn(Optional.of(report));
        when(reportRepository.findByTargetTypeAndTargetIdAndStatus(any(), anyLong(), any()))
                .thenReturn(List.of(report));

        service.resolve(5L, ACTOR, false, new ResolveReportRequest(ReportAction.DELETE_COMMENT, null));

        verify(commentService).delete(VIDEO_ID, COMMENT_ID, ACTOR, true);
    }

    @Test
    void onlyAdminCanLockAUser() {
        Report report = pending(ReportTargetType.USER, OWNER);
        when(reportRepository.findById(5L)).thenReturn(Optional.of(report));

        assertThatThrownBy(() -> service.resolve(5L, ACTOR, false,
                new ResolveReportRequest(ReportAction.LOCK_USER, null)))
                .isInstanceOfSatisfying(AppException.class, e -> assertThat(e.getStatus()).isEqualTo(403));
        assertThat(owner.getIsActive()).isTrue();
    }

    @Test
    void lockingAUserDeactivatesAndSignsThemOut() {
        Report report = pending(ReportTargetType.USER, OWNER);
        when(reportRepository.findById(5L)).thenReturn(Optional.of(report));
        when(reportRepository.findByTargetTypeAndTargetIdAndStatus(any(), anyLong(), any()))
                .thenReturn(List.of(report));

        service.resolve(5L, ACTOR, true, new ResolveReportRequest(ReportAction.LOCK_USER, "spam liên tục"));

        assertThat(owner.getIsActive()).isFalse();
        verify(refreshTokenService).revokeAll(OWNER);
    }

    @Test
    void staffAccountsCannotBeLockedThroughAReport() {
        owner.setRole(UserRole.MODERATOR);
        Report report = pending(ReportTargetType.USER, OWNER);
        when(reportRepository.findById(5L)).thenReturn(Optional.of(report));

        assertThatThrownBy(() -> service.resolve(5L, ACTOR, true,
                new ResolveReportRequest(ReportAction.LOCK_USER, null)))
                .isInstanceOfSatisfying(AppException.class, e -> assertThat(e.getStatus()).isEqualTo(400));
        assertThat(owner.getIsActive()).isTrue();
        verify(refreshTokenService, never()).revokeAll(anyLong());
    }

    @Test
    void anAlreadyHandledReportCannotBeHandledAgain() {
        Report report = pending(ReportTargetType.VIDEO, VIDEO_ID);
        report.setStatus(ReportStatus.DISMISSED);
        when(reportRepository.findById(5L)).thenReturn(Optional.of(report));

        assertThatThrownBy(() -> service.dismiss(5L, ACTOR, "x"))
                .isInstanceOfSatisfying(AppException.class, e -> assertThat(e.getStatus()).isEqualTo(400));
    }

    @Test
    void dismissMarksPendingReportsWithoutAnyAction() {
        Report report = pending(ReportTargetType.VIDEO, VIDEO_ID);
        when(reportRepository.findById(5L)).thenReturn(Optional.of(report));
        when(reportRepository.findByTargetTypeAndTargetIdAndStatus(any(), anyLong(), any()))
                .thenReturn(List.of(report));

        service.dismiss(5L, ACTOR, "  không vi phạm ");

        assertThat(report.getStatus()).isEqualTo(ReportStatus.DISMISSED);
        assertThat(report.getAction()).isNull();
        assertThat(report.getResolutionNote()).isEqualTo("không vi phạm");
        verify(videoService, never()).rejectVideo(anyLong(), anyLong(), any());
    }
}
