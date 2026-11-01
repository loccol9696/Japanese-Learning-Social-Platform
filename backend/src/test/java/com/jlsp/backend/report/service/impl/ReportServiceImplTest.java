package com.jlsp.backend.report.service.impl;

import com.jlsp.backend.chat.entity.Conversation;
import com.jlsp.backend.chat.entity.Message;
import com.jlsp.backend.chat.entity.MessageType;
import com.jlsp.backend.chat.repository.MessageRepository;
import com.jlsp.backend.chat.service.ChatService;
import com.jlsp.backend.common.exception.AppException;
import com.jlsp.backend.common.security.token.RefreshTokenService;
import com.jlsp.backend.notification.entity.NotificationType;
import com.jlsp.backend.notification.service.NotificationService;
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
import org.springframework.context.ApplicationEventPublisher;

import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.isNull;
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
    private static final long MESSAGE_ID = 80L;
    private static final long STRANGER = 3L;

    private ReportRepository reportRepository;
    private UserRepository userRepository;
    private VideoRepository videoRepository;
    private VideoCommentRepository commentRepository;
    private MessageRepository messageRepository;
    private ChatService chatService;
    private NotificationService notificationService;
    private ApplicationEventPublisher eventPublisher;
    private VideoService videoService;
    private CommentService commentService;
    private RefreshTokenService refreshTokenService;
    private ReportServiceImpl service;

    private User reporter;
    private User owner;
    private com.jlsp.backend.common.security.ratelimit.RateLimiter rateLimiter;
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
        rateLimiter = mock(com.jlsp.backend.common.security.ratelimit.RateLimiter.class);
        when(rateLimiter.tryAcquire(anyString(), anyInt(), any()))
                .thenReturn(com.jlsp.backend.common.security.ratelimit.RateLimiter.Decision.ALLOWED);
        messageRepository = mock(MessageRepository.class);
        chatService = mock(ChatService.class);
        notificationService = mock(NotificationService.class);
        eventPublisher = mock(ApplicationEventPublisher.class);
        service = new ReportServiceImpl(reportRepository, userRepository, videoRepository, commentRepository,
                messageRepository, videoService, commentService, chatService, refreshTokenService,
                notificationService, rateLimiter, eventPublisher);

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
        return new CreateReportRequest(type, id, ReportReason.SPAM, " quảng cáo ", null, null);
    }

    private static CreateReportRequest lineRequest(ReportTargetType type, Integer index, String pattern) {
        return new CreateReportRequest(type, VIDEO_ID, ReportReason.INACCURATE, null, index, pattern);
    }

    /** Video có một câu phụ đề kèm bản dịch và một mẫu ngữ pháp. */
    private void givenVideoHasASubtitleLine() {
        video.setSubtitles("""
                [{"text":"食べている","translation":"dang an","start":0,"end":1}]""");
        video.setGrammarAnalysis("""
                [{"index":0,"text":"食べている","grammarPoints":[
                  {"pattern":"〜ている","matchedText":"ている","meaning":"dang","explanation":"tiep dien"}]}]""");
    }

    /** Dùng đúng nội dung tạo báo cáo làm báo cáo đang chờ, kèm repository trả về nó. */
    private Report pendingFrom(Report report) {
        when(reportRepository.findById(5L)).thenReturn(Optional.of(report));
        when(reportRepository.findByTargetTypeAndTargetIdAndTargetKeyAndStatus(any(), anyLong(), any(), any()))
                .thenReturn(List.of(report));
        return report;
    }

    private Report createdReport(CreateReportRequest request) {
        org.mockito.ArgumentCaptor<Report> saved = org.mockito.ArgumentCaptor.forClass(Report.class);
        service.create(REPORTER, request);
        verify(reportRepository).save(saved.capture());
        Report report = saved.getValue();
        report.setId(5L);
        return pendingFrom(report);
    }

    private Message message() {
        Conversation conversation = Conversation.builder().id(30L).userLow(reporter).userHigh(owner).build();
        return Message.builder().id(MESSAGE_ID).conversation(conversation).sender(owner)
                .type(MessageType.TEXT).content("tin nhắn xúc phạm").build();
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
        when(reportRepository.existsByReporterIdAndTargetTypeAndTargetIdAndTargetKeyAndStatus(
                REPORTER, ReportTargetType.VIDEO, VIDEO_ID, "", ReportStatus.PENDING)).thenReturn(true);

        assertThatThrownBy(() -> service.create(REPORTER, request(ReportTargetType.VIDEO, VIDEO_ID)))
                .isInstanceOfSatisfying(AppException.class, e -> assertThat(e.getStatus()).isEqualTo(409));
        verify(reportRepository, never()).save(any());
    }

    @Test
    void tooManyReportsInAnHourAreRejectedWith429AndNothingIsSaved() {
        when(rateLimiter.tryAcquire("report:" + REPORTER, ReportServiceImpl.MAX_REPORTS_PER_HOUR,
                java.time.Duration.ofHours(1)))
                .thenReturn(new com.jlsp.backend.common.security.ratelimit.RateLimiter.Decision(false, 600));

        assertThatThrownBy(() -> service.create(REPORTER, request(ReportTargetType.VIDEO, VIDEO_ID)))
                .isInstanceOfSatisfying(AppException.class, e -> assertThat(e.getStatus()).isEqualTo(429));
        verify(reportRepository, never()).save(any());
    }

    @Test
    void rejectedReportsDoNotConsumeTheRateLimit() {
        assertThatThrownBy(() -> service.create(OWNER, request(ReportTargetType.VIDEO, VIDEO_ID)))
                .isInstanceOf(AppException.class);

        verify(rateLimiter, never()).tryAcquire(anyString(), org.mockito.ArgumentMatchers.anyInt(), any());
    }

    // ---- tin nhắn

    @Test
    void reportingAMessageKeepsItsContentAsEvidence() {
        when(messageRepository.findById(MESSAGE_ID)).thenReturn(Optional.of(message()));

        ReportResponse response = service.create(REPORTER, request(ReportTargetType.MESSAGE, MESSAGE_ID));

        assertThat(response.getTargetSnapshot()).isEqualTo("tin nhắn xúc phạm");
        assertThat(response.getTargetOwnerId()).isEqualTo(OWNER);
    }

    @Test
    void someoneOutsideTheConversationCannotReportOrProbeAMessage() {
        when(messageRepository.findById(MESSAGE_ID)).thenReturn(Optional.of(message()));
        when(userRepository.findById(STRANGER)).thenReturn(Optional.of(User.builder().id(STRANGER).build()));

        assertThatThrownBy(() -> service.create(STRANGER, request(ReportTargetType.MESSAGE, MESSAGE_ID)))
                .isInstanceOfSatisfying(AppException.class, e -> assertThat(e.getStatus()).isEqualTo(404));
        verify(reportRepository, never()).save(any());
    }

    @Test
    void cannotReportYourOwnMessage() {
        when(messageRepository.findById(MESSAGE_ID)).thenReturn(Optional.of(message()));

        assertThatThrownBy(() -> service.create(OWNER, request(ReportTargetType.MESSAGE, MESSAGE_ID)))
                .isInstanceOfSatisfying(AppException.class, e -> assertThat(e.getStatus()).isEqualTo(400));
    }

    @Test
    void imageMessageSnapshotKeepsTheImage() {
        Message image = message();
        image.setType(MessageType.IMAGE);
        image.setContent(null);
        image.setImageUrl("https://res.cloudinary.com/x.jpg");
        when(messageRepository.findById(MESSAGE_ID)).thenReturn(Optional.of(image));

        Report report = createdReport(request(ReportTargetType.MESSAGE, MESSAGE_ID));

        assertThat(report.getTargetSnapshot()).isEqualTo("[Ảnh]");
        assertThat(report.getSnapshotImageUrl()).isEqualTo("https://res.cloudinary.com/x.jpg");
    }

    @Test
    void snapshotSurvivesTheSenderRecallingTheMessage() {
        Message message = message();
        when(messageRepository.findById(MESSAGE_ID)).thenReturn(Optional.of(message));
        Report report = createdReport(request(ReportTargetType.MESSAGE, MESSAGE_ID));

        message.setContent(null);
        message.setRecalledAt(java.time.LocalDateTime.now());
        ReportResponse response = service.dismiss(5L, ACTOR, null);

        assertThat(report.getStatus()).isEqualTo(ReportStatus.DISMISSED);
        assertThat(response.getTargetExists()).isFalse();
        assertThat(response.getTargetSnapshot()).isEqualTo("tin nhắn xúc phạm");
    }

    @Test
    void hidingAMessageRemovesItAndTellsTheSenderWhy() {
        when(messageRepository.findById(MESSAGE_ID)).thenReturn(Optional.of(message()));
        createdReport(request(ReportTargetType.MESSAGE, MESSAGE_ID));

        service.resolve(5L, ACTOR, false, new ResolveReportRequest(ReportAction.HIDE_MESSAGE, "lần đầu", null));

        verify(chatService).removeMessageByModeration(MESSAGE_ID);
        verify(notificationService).notifyReportResult(eq(OWNER), eq(NotificationType.CONTENT_REMOVED), isNull(),
                eq(5L), eq("Tin nhắn của bạn đã bị gỡ. Lý do: spam hoặc quảng cáo. lần đầu"));
        verify(notificationService).notifyReportResult(eq(REPORTER), eq(NotificationType.REPORT_UPDATE), isNull(),
                eq(5L), anyString());
    }

    @Test
    void hidingAnAlreadyRecalledMessageDoesNothingToIt() {
        Message message = message();
        when(messageRepository.findById(MESSAGE_ID)).thenReturn(Optional.of(message));
        createdReport(request(ReportTargetType.MESSAGE, MESSAGE_ID));
        message.setRecalledAt(java.time.LocalDateTime.now());

        service.resolve(5L, ACTOR, false, new ResolveReportRequest(ReportAction.HIDE_MESSAGE, null, null));

        verify(chatService, never()).removeMessageByModeration(anyLong());
        verify(notificationService, never()).notifyReportResult(eq(OWNER), any(), any(), any(), anyString());
    }

    @Test
    void hideMessageIsOnlyForMessageReports() {
        pendingFrom(pending(ReportTargetType.VIDEO, VIDEO_ID));

        assertThatThrownBy(() -> service.resolve(5L, ACTOR, false,
                new ResolveReportRequest(ReportAction.HIDE_MESSAGE, null, null)))
                .isInstanceOfSatisfying(AppException.class, e -> assertThat(e.getStatus()).isEqualTo(400));
    }

    // ---- bản dịch và ngữ pháp

    @Test
    void reportingATranslationStoresTheLineAndKeepsItSeparateFromOtherLines() {
        givenVideoHasASubtitleLine();

        Report report = createdReport(lineRequest(ReportTargetType.TRANSLATION, 0, null));

        assertThat(report.getTargetKey()).isEqualTo("0");
        assertThat(report.getTargetSnapshot()).isEqualTo("Câu: 食べている\nBản dịch: dang an");
    }

    @Test
    void reportingGrammarStoresThePatternAndExplanation() {
        givenVideoHasASubtitleLine();

        Report report = createdReport(lineRequest(ReportTargetType.GRAMMAR, 0, "〜ている"));

        assertThat(report.getTargetKey()).isEqualTo("0:〜ている");
        assertThat(report.getTargetSnapshot()).contains("Mẫu: 〜ている", "Nghĩa: dang", "Giải thích: tiep dien");
    }

    @Test
    void lineReportsRequireTheLineAndThePattern() {
        givenVideoHasASubtitleLine();

        assertThatThrownBy(() -> service.create(REPORTER, lineRequest(ReportTargetType.TRANSLATION, null, null)))
                .isInstanceOfSatisfying(AppException.class, e -> assertThat(e.getStatus()).isEqualTo(400));
        assertThatThrownBy(() -> service.create(REPORTER, lineRequest(ReportTargetType.GRAMMAR, 0, " ")))
                .isInstanceOfSatisfying(AppException.class, e -> assertThat(e.getStatus()).isEqualTo(400));
    }

    @Test
    void cannotReportALineOrPatternThatDoesNotExist() {
        givenVideoHasASubtitleLine();

        assertThatThrownBy(() -> service.create(REPORTER, lineRequest(ReportTargetType.TRANSLATION, 9, null)))
                .isInstanceOfSatisfying(AppException.class, e -> assertThat(e.getStatus()).isEqualTo(404));
        assertThatThrownBy(() -> service.create(REPORTER, lineRequest(ReportTargetType.GRAMMAR, 0, "〜たい")))
                .isInstanceOfSatisfying(AppException.class, e -> assertThat(e.getStatus()).isEqualTo(404));
    }

    @Test
    void privateVideoSubtitlesCannotBeProbedThroughReports() {
        givenVideoHasASubtitleLine();
        video.setStatus(VideoStatus.PRIVATE);

        assertThatThrownBy(() -> service.create(REPORTER, lineRequest(ReportTargetType.TRANSLATION, 0, null)))
                .isInstanceOfSatisfying(AppException.class, e -> assertThat(e.getStatus()).isEqualTo(404));
        verify(reportRepository, never()).save(any());
    }

    @Test
    void removingATranslationClearsOnlyThatLineAndKeepsGrammar() {
        givenVideoHasASubtitleLine();
        String grammar = video.getGrammarAnalysis();
        createdReport(lineRequest(ReportTargetType.TRANSLATION, 0, null));

        service.resolve(5L, ACTOR, false, new ResolveReportRequest(ReportAction.REMOVE_TRANSLATION, null, null));

        assertThat(SubtitleLines.find(video.getSubtitles(), 0).orElseThrow().translation()).isEmpty();
        assertThat(video.getGrammarAnalysis()).isEqualTo(grammar);
        verify(videoRepository).save(video);
        verify(notificationService).notifyReportResult(eq(OWNER), eq(NotificationType.CONTENT_REMOVED), eq(VIDEO_ID),
                eq(5L), eq("Một bản dịch trong video của bạn đã bị gỡ. Lý do: dịch hoặc giải thích sai"));
    }

    @Test
    void removingATranslationTheOwnerAlreadyChangedLeavesTheNewTextAlone() {
        givenVideoHasASubtitleLine();
        createdReport(lineRequest(ReportTargetType.TRANSLATION, 0, null));
        String edited = """
                [{"text":"食べている","translation":"dang an com","start":0,"end":1}]""";
        video.setSubtitles(edited);

        ReportResponse response = service.resolve(5L, ACTOR, false,
                new ResolveReportRequest(ReportAction.REMOVE_TRANSLATION, null, null));

        assertThat(video.getSubtitles()).isEqualTo(edited);
        assertThat(response.getTargetExists()).isFalse();
        verify(videoRepository, never()).save(any());
    }

    @Test
    void removingGrammarDropsThePattern() {
        givenVideoHasASubtitleLine();
        createdReport(lineRequest(ReportTargetType.GRAMMAR, 0, "〜ている"));

        service.resolve(5L, ACTOR, false, new ResolveReportRequest(ReportAction.REMOVE_GRAMMAR, null, null));

        assertThat(SubtitleLines.findGrammar(video.getSubtitles(), video.getGrammarAnalysis(), 0, "〜ている")).isEmpty();
        verify(notificationService).notifyReportResult(eq(OWNER), eq(NotificationType.CONTENT_REMOVED), eq(VIDEO_ID),
                eq(5L), anyString());
    }

    @Test
    void reportsOnDifferentLinesAreClosedSeparately() {
        givenVideoHasASubtitleLine();
        createdReport(lineRequest(ReportTargetType.TRANSLATION, 0, null));

        service.dismiss(5L, ACTOR, null);

        verify(reportRepository).findByTargetTypeAndTargetIdAndTargetKeyAndStatus(
                ReportTargetType.TRANSLATION, VIDEO_ID, "0", ReportStatus.PENDING);
    }

    @Test
    void reporterOfATranslationCanOpenTheVideoFromTheNotification() {
        givenVideoHasASubtitleLine();
        createdReport(lineRequest(ReportTargetType.TRANSLATION, 0, null));

        service.dismiss(5L, ACTOR, null);

        verify(notificationService).notifyReportResult(eq(REPORTER), eq(NotificationType.REPORT_UPDATE), eq(VIDEO_ID),
                eq(5L), anyString());
    }

    @Test
    void deletingACommentTellsTheOwnerTheReason() {
        VideoComment comment = VideoComment.builder().id(COMMENT_ID).video(video).user(owner)
                .content("bình luận xấu").build();
        when(commentRepository.findById(COMMENT_ID)).thenReturn(Optional.of(comment));
        pendingFrom(pending(ReportTargetType.COMMENT, COMMENT_ID));

        service.resolve(5L, ACTOR, false, new ResolveReportRequest(ReportAction.DELETE_COMMENT, null, null));

        verify(notificationService).notifyReportResult(eq(OWNER), eq(NotificationType.CONTENT_REMOVED), eq(VIDEO_ID),
                eq(5L), eq("Bình luận của bạn đã bị xóa. Lý do: spam hoặc quảng cáo"));
    }

    // ---- kiểm duyệt viên sửa nội dung

    private static ResolveReportRequest editTranslation(String translation) {
        return new ResolveReportRequest(ReportAction.EDIT_TRANSLATION, "dịch lại cho đúng",
                ReportCorrection.builder().translation(translation).build());
    }

    private static ResolveReportRequest editGrammar(String pattern, String meaning, String explanation) {
        return new ResolveReportRequest(ReportAction.EDIT_GRAMMAR, null, ReportCorrection.builder()
                .pattern(pattern).meaning(meaning).explanation(explanation).build());
    }

    @Test
    void pendingReportPrefillsTheCurrentContentForEditing() {
        givenVideoHasASubtitleLine();

        ReportResponse response = service.create(REPORTER, lineRequest(ReportTargetType.GRAMMAR, 0, "〜ている"));

        assertThat(response.getTargetContent().getPattern()).isEqualTo("〜ている");
        assertThat(response.getTargetContent().getMeaning()).isEqualTo("dang");
        assertThat(response.getTargetContent().getExplanation()).isEqualTo("tiep dien");
    }

    @Test
    void editingATranslationSavesItAndTellsTheOwnerItWasEditedNotRemoved() {
        givenVideoHasASubtitleLine();
        String grammar = video.getGrammarAnalysis();
        Report report = createdReport(lineRequest(ReportTargetType.TRANSLATION, 0, null));

        service.resolve(5L, ACTOR, false, editTranslation("  đang ăn  "));

        assertThat(SubtitleLines.find(video.getSubtitles(), 0).orElseThrow().translation()).isEqualTo("đang ăn");
        assertThat(video.getGrammarAnalysis()).isEqualTo(grammar);
        assertThat(report.getStatus()).isEqualTo(ReportStatus.RESOLVED);
        assertThat(report.getAction()).isEqualTo(ReportAction.EDIT_TRANSLATION);
        verify(videoRepository).save(video);
        verify(notificationService).notifyReportResult(eq(OWNER), eq(NotificationType.CONTENT_EDITED), eq(VIDEO_ID),
                eq(5L), eq("Một bản dịch trong video của bạn đã được sửa lại. "
                        + "Lý do: dịch hoặc giải thích sai. dịch lại cho đúng"));
        verify(notificationService, never()).notifyReportResult(any(), eq(NotificationType.CONTENT_REMOVED),
                any(), any(), anyString());
    }

    @Test
    void editingGrammarUpdatesThePatternAndKeepsWhereItIsUnderlined() {
        givenVideoHasASubtitleLine();
        createdReport(lineRequest(ReportTargetType.GRAMMAR, 0, "〜ている"));

        service.resolve(5L, ACTOR, false, editGrammar("〜ていた", "đã đang", "quá khứ tiếp diễn"));

        SubtitleLines.Grammar edited = SubtitleLines
                .findGrammar(video.getSubtitles(), video.getGrammarAnalysis(), 0, "〜ていた").orElseThrow();
        assertThat(edited.meaning()).isEqualTo("đã đang");
        assertThat(edited.explanation()).isEqualTo("quá khứ tiếp diễn");
        assertThat(edited.matchedText()).isEqualTo("ている");
        assertThat(SubtitleLines.findGrammar(video.getSubtitles(), video.getGrammarAnalysis(), 0, "〜ている")).isEmpty();
        verify(notificationService).notifyReportResult(eq(OWNER), eq(NotificationType.CONTENT_EDITED), eq(VIDEO_ID),
                eq(5L), anyString());
    }

    @Test
    void editingRequiresTheCorrectedText() {
        givenVideoHasASubtitleLine();
        Report report = createdReport(lineRequest(ReportTargetType.TRANSLATION, 0, null));

        assertThatThrownBy(() -> service.resolve(5L, ACTOR, false, editTranslation("  ")))
                .isInstanceOfSatisfying(AppException.class, e -> assertThat(e.getStatus()).isEqualTo(400));
        assertThatThrownBy(() -> service.resolve(5L, ACTOR, false,
                new ResolveReportRequest(ReportAction.EDIT_TRANSLATION, null, null)))
                .isInstanceOfSatisfying(AppException.class, e -> assertThat(e.getStatus()).isEqualTo(400));
        assertThat(report.getStatus()).isEqualTo(ReportStatus.PENDING);
        verify(videoRepository, never()).save(any());
    }

    @Test
    void editingGrammarRequiresPatternAndMeaningButNotExplanation() {
        givenVideoHasASubtitleLine();
        createdReport(lineRequest(ReportTargetType.GRAMMAR, 0, "〜ている"));

        assertThatThrownBy(() -> service.resolve(5L, ACTOR, false, editGrammar("〜ている", " ", "x")))
                .isInstanceOfSatisfying(AppException.class, e -> assertThat(e.getStatus()).isEqualTo(400));

        service.resolve(5L, ACTOR, false, editGrammar("〜ている", "đang", null));

        assertThat(SubtitleLines.findGrammar(video.getSubtitles(), video.getGrammarAnalysis(), 0, "〜ている")
                .orElseThrow().explanation()).isEmpty();
    }

    @Test
    void cannotEditContentTheOwnerChangedAfterTheReport() {
        givenVideoHasASubtitleLine();
        Report report = createdReport(lineRequest(ReportTargetType.TRANSLATION, 0, null));
        String edited = """
                [{"text":"食べている","translation":"dang an com","start":0,"end":1}]""";
        video.setSubtitles(edited);

        assertThatThrownBy(() -> service.resolve(5L, ACTOR, false, editTranslation("mới")))
                .isInstanceOfSatisfying(AppException.class, e -> assertThat(e.getStatus()).isEqualTo(409));
        assertThat(video.getSubtitles()).isEqualTo(edited);
        assertThat(report.getStatus()).isEqualTo(ReportStatus.PENDING);
    }

    @Test
    void editActionMustMatchTheReportType() {
        givenVideoHasASubtitleLine();
        pendingFrom(pending(ReportTargetType.VIDEO, VIDEO_ID));

        assertThatThrownBy(() -> service.resolve(5L, ACTOR, false, editTranslation("x")))
                .isInstanceOfSatisfying(AppException.class, e -> assertThat(e.getStatus()).isEqualTo(400));
    }

    // ---- nhắc nhở

    private static ResolveReportRequest warn(String note) {
        return new ResolveReportRequest(ReportAction.WARN_USER, note, null);
    }

    @Test
    void warningCountsOneViolationAndTellsTheOwnerTheReason() {
        pendingFrom(pending(ReportTargetType.VIDEO, VIDEO_ID));

        service.resolve(5L, ACTOR, false, warn("lần đầu"));

        verify(userRepository).incrementViolationCount(OWNER);
        verify(notificationService).notifyReportResult(eq(OWNER), eq(NotificationType.VIOLATION_WARNING), eq(VIDEO_ID),
                eq(5L), eq("Video của bạn đã vi phạm tiêu chuẩn cộng đồng. Lý do: spam hoặc quảng cáo. lần đầu"));
    }

    @Test
    void warningDoesNotRemoveTheContent() {
        pendingFrom(pending(ReportTargetType.VIDEO, VIDEO_ID));

        service.resolve(5L, ACTOR, false, warn(null));

        verify(videoService, never()).rejectVideo(anyLong(), anyLong(), any());
    }

    @Test
    void severalReportsOfOneTargetCountAsOneViolation() {
        Report first = pending(ReportTargetType.VIDEO, VIDEO_ID);
        Report second = pending(ReportTargetType.VIDEO, VIDEO_ID);
        when(reportRepository.findById(5L)).thenReturn(Optional.of(first));
        when(reportRepository.findByTargetTypeAndTargetIdAndTargetKeyAndStatus(any(), anyLong(), any(), any()))
                .thenReturn(List.of(first, second));

        service.resolve(5L, ACTOR, false, warn(null));

        verify(userRepository, org.mockito.Mockito.times(1)).incrementViolationCount(OWNER);
        assertThat(second.getAction()).isEqualTo(ReportAction.WARN_USER);
    }

    @Test
    void aSenderWhoRecalledTheMessageCanStillBeWarned() {
        Message message = message();
        when(messageRepository.findById(MESSAGE_ID)).thenReturn(Optional.of(message));
        createdReport(request(ReportTargetType.MESSAGE, MESSAGE_ID));
        message.setRecalledAt(java.time.LocalDateTime.now());

        service.resolve(5L, ACTOR, false, warn(null));

        verify(userRepository).incrementViolationCount(OWNER);
        verify(notificationService).notifyReportResult(eq(OWNER), eq(NotificationType.VIOLATION_WARNING), isNull(),
                eq(5L), eq("Tin nhắn của bạn đã vi phạm tiêu chuẩn cộng đồng. Lý do: spam hoặc quảng cáo"));
    }

    @Test
    void cannotWarnWhenTheOwnerIsUnknown() {
        when(videoRepository.findById(VIDEO_ID)).thenReturn(Optional.empty());
        Report report = pendingFrom(pending(ReportTargetType.VIDEO, VIDEO_ID));

        assertThatThrownBy(() -> service.resolve(5L, ACTOR, false, warn(null)))
                .isInstanceOfSatisfying(AppException.class, e -> assertThat(e.getStatus()).isEqualTo(400));
        verify(userRepository, never()).incrementViolationCount(anyLong());
        assertThat(report.getStatus()).isEqualTo(ReportStatus.PENDING);
    }

    @Test
    void moderatorSeesHowManyViolationsTheOwnerHas() {
        owner.setViolationCount(3);
        pendingFrom(pending(ReportTargetType.VIDEO, VIDEO_ID));

        assertThat(service.dismiss(5L, ACTOR, null).getTargetOwnerViolationCount()).isEqualTo(3);
    }

    @Test
    void reporterDoesNotLearnTheOwnersViolationCount() {
        owner.setViolationCount(3);

        ReportResponse response = service.create(REPORTER, request(ReportTargetType.VIDEO, VIDEO_ID));

        assertThat(response.getTargetOwnerViolationCount()).isNull();
    }

    @Test
    void removingContentDoesNotCountAViolation() {
        VideoComment comment = VideoComment.builder().id(COMMENT_ID).video(video).user(owner)
                .content("bình luận xấu").build();
        when(commentRepository.findById(COMMENT_ID)).thenReturn(Optional.of(comment));
        pendingFrom(pending(ReportTargetType.COMMENT, COMMENT_ID));

        service.resolve(5L, ACTOR, false, new ResolveReportRequest(ReportAction.DELETE_COMMENT, null, null));

        verify(userRepository, never()).incrementViolationCount(anyLong());
    }

    // ---- khóa tài khoản từ báo cáo

    @Test
    void lockingEmailsTheOwnerTheReason() {
        owner.setEmail("owner@example.com");
        owner.setDisplayName("Hana");
        pendingFrom(pending(ReportTargetType.USER, OWNER));

        service.resolve(5L, ACTOR, true, new ResolveReportRequest(ReportAction.LOCK_USER, "tái phạm nhiều lần", null));

        verify(eventPublisher).publishEvent(new AccountLockedEvent("owner@example.com", "Hana",
                "spam hoặc quảng cáo. tái phạm nhiều lần"));
    }

    @Test
    void lockingRecordsTheLockSoOtpCannotReactivateTheAccount() {
        pendingFrom(pending(ReportTargetType.USER, OWNER));

        service.resolve(5L, ACTOR, true, new ResolveReportRequest(ReportAction.LOCK_USER, null, null));

        assertThat(owner.getLockedAt()).isNotNull();
    }

    @Test
    void lockMailFallsBackToTheUsernameWithoutADisplayName() {
        owner.setEmail("owner@example.com");
        pendingFrom(pending(ReportTargetType.USER, OWNER));

        service.resolve(5L, ACTOR, true, new ResolveReportRequest(ReportAction.LOCK_USER, null, null));

        verify(eventPublisher).publishEvent(new AccountLockedEvent("owner@example.com", "owner", "spam hoặc quảng cáo"));
    }

    @Test
    void lockingAnAlreadyLockedAccountDoesNotEmailAgain() {
        owner.setIsActive(false);
        owner.setLockedAt(java.time.LocalDateTime.now());
        pendingFrom(pending(ReportTargetType.USER, OWNER));

        service.resolve(5L, ACTOR, true, new ResolveReportRequest(ReportAction.LOCK_USER, null, null));

        verify(eventPublisher, never()).publishEvent(any(Object.class));
    }

    @Test
    void refusedLockSendsNoMail() {
        owner.setRole(UserRole.MODERATOR);
        pendingFrom(pending(ReportTargetType.USER, OWNER));

        assertThatThrownBy(() -> service.resolve(5L, ACTOR, true,
                new ResolveReportRequest(ReportAction.LOCK_USER, null, null)))
                .isInstanceOf(AppException.class);
        verify(eventPublisher, never()).publishEvent(any(Object.class));
    }

    @Test
    void adminCanLockASenderWhoRecalledTheReportedMessage() {
        Message message = message();
        when(messageRepository.findById(MESSAGE_ID)).thenReturn(Optional.of(message));
        createdReport(request(ReportTargetType.MESSAGE, MESSAGE_ID));
        message.setRecalledAt(java.time.LocalDateTime.now());

        ReportResponse response = service.resolve(5L, ACTOR, true,
                new ResolveReportRequest(ReportAction.LOCK_USER, null, null));

        assertThat(owner.getIsActive()).isFalse();
        verify(refreshTokenService).revokeAll(OWNER);
        assertThat(response.getTargetExists()).isFalse();
        assertThat(response.getTargetOwnerUsername()).isEqualTo("owner");
    }

    @Test
    void adminCanLockTheOwnerAfterAReportedLineWasChanged() {
        givenVideoHasASubtitleLine();
        createdReport(lineRequest(ReportTargetType.TRANSLATION, 0, null));
        video.setSubtitles("[]");

        service.resolve(5L, ACTOR, true, new ResolveReportRequest(ReportAction.LOCK_USER, null, null));

        assertThat(owner.getIsActive()).isFalse();
    }

    @Test
    void lockingIsRefusedOnlyWhenTheOwnerIsUnknown() {
        when(videoRepository.findById(VIDEO_ID)).thenReturn(Optional.empty());
        Report report = pendingFrom(pending(ReportTargetType.VIDEO, VIDEO_ID));

        assertThatThrownBy(() -> service.resolve(5L, ACTOR, true,
                new ResolveReportRequest(ReportAction.LOCK_USER, null, null)))
                .isInstanceOfSatisfying(AppException.class, e -> assertThat(e.getStatus()).isEqualTo(400));
        assertThat(report.getStatus()).isEqualTo(ReportStatus.PENDING);
    }

    // ---- xem kết quả báo cáo

    private Report closedMessageReport() {
        Report report = pending(ReportTargetType.MESSAGE, MESSAGE_ID);
        report.setTargetSnapshot("tin xúc phạm");
        report.setDetail("lăng mạ tôi");
        report.setStatus(ReportStatus.RESOLVED);
        report.setAction(ReportAction.WARN_USER);
        report.setResolutionNote("lần đầu nhắc nhở");
        when(reportRepository.findById(5L)).thenReturn(Optional.of(report));
        return report;
    }

    @Test
    void reporterSeesWhatTheyReportedAndTheOutcomeButNotTheNoteForTheOwner() {
        closedMessageReport();

        ReportResultResponse result = service.getResult(REPORTER, 5L);

        assertThat(result.getContent()).isEqualTo("tin xúc phạm");
        assertThat(result.getDetail()).isEqualTo("lăng mạ tôi");
        assertThat(result.getOutcome()).isEqualTo("Đã nhắc nhở chủ nội dung");
        assertThat(result.getNote()).isNull();
    }

    @Test
    void reporterSeesTheModeratorsNoteWhenDismissed() {
        Report report = closedMessageReport();
        report.setStatus(ReportStatus.DISMISSED);
        report.setAction(null);
        report.setResolutionNote("nội dung không vi phạm");

        ReportResultResponse result = service.getResult(REPORTER, 5L);

        assertThat(result.getOutcome()).isEqualTo("Không phát hiện vi phạm");
        assertThat(result.getNote()).isEqualTo("nội dung không vi phạm");
    }

    @Test
    void ownerSeesTheNoteButNotTheReportersDescription() {
        closedMessageReport();
        when(notificationService.wasNotifiedAboutReport(OWNER, 5L)).thenReturn(true);

        ReportResultResponse result = service.getResult(OWNER, 5L);

        assertThat(result.getOutcome()).isEqualTo("Bạn đã bị nhắc nhở");
        assertThat(result.getNote()).isEqualTo("lần đầu nhắc nhở");
        assertThat(result.getDetail()).isNull();
    }

    @Test
    void anyoneElseGetsNotFoundLikeAMissingReport() {
        closedMessageReport();

        assertThatThrownBy(() -> service.getResult(STRANGER, 5L))
                .isInstanceOf(com.jlsp.backend.common.exception.ResourceNotFoundException.class);
    }

    @Test
    void resultFallsBackToTheCurrentTitleWithoutASnapshot() {
        when(reportRepository.findById(5L)).thenReturn(Optional.of(pending(ReportTargetType.VIDEO, VIDEO_ID)));

        ReportResultResponse result = service.getResult(REPORTER, 5L);

        assertThat(result.getContent()).isEqualTo("Video vi phạm");
        assertThat(result.getOutcome()).isEqualTo("Báo cáo đang chờ xử lý");
    }

    // ---- resolve / dismiss

    @Test
    void resolveClosesEveryPendingReportOfTheSameTarget() {
        Report first = pending(ReportTargetType.VIDEO, VIDEO_ID);
        Report second = pending(ReportTargetType.VIDEO, VIDEO_ID);
        when(reportRepository.findById(5L)).thenReturn(Optional.of(first));
        when(reportRepository.findByTargetTypeAndTargetIdAndTargetKeyAndStatus(
                ReportTargetType.VIDEO, VIDEO_ID, "", ReportStatus.PENDING)).thenReturn(List.of(first, second));

        service.resolve(5L, ACTOR, false, new ResolveReportRequest(ReportAction.HIDE_VIDEO, "ok", null));

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
        when(reportRepository.findByTargetTypeAndTargetIdAndTargetKeyAndStatus(any(), anyLong(), any(), any()))
                .thenReturn(List.of(report));

        service.resolve(5L, ACTOR, false, new ResolveReportRequest(ReportAction.HIDE_VIDEO, null, null));

        verify(videoService, never()).rejectVideo(anyLong(), anyLong(), any());
        assertThat(report.getStatus()).isEqualTo(ReportStatus.RESOLVED);
    }

    @Test
    void actionMustMatchTheTargetType() {
        Report report = pending(ReportTargetType.USER, OWNER);
        when(reportRepository.findById(5L)).thenReturn(Optional.of(report));

        assertThatThrownBy(() -> service.resolve(5L, ACTOR, true,
                new ResolveReportRequest(ReportAction.HIDE_VIDEO, null, null)))
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
        when(reportRepository.findByTargetTypeAndTargetIdAndTargetKeyAndStatus(any(), anyLong(), any(), any()))
                .thenReturn(List.of(report));

        service.resolve(5L, ACTOR, false, new ResolveReportRequest(ReportAction.DELETE_COMMENT, null, null));

        verify(commentService).delete(VIDEO_ID, COMMENT_ID, ACTOR, true);
    }

    @Test
    void onlyAdminCanLockAUser() {
        Report report = pending(ReportTargetType.USER, OWNER);
        when(reportRepository.findById(5L)).thenReturn(Optional.of(report));

        assertThatThrownBy(() -> service.resolve(5L, ACTOR, false,
                new ResolveReportRequest(ReportAction.LOCK_USER, null, null)))
                .isInstanceOfSatisfying(AppException.class, e -> assertThat(e.getStatus()).isEqualTo(403));
        assertThat(owner.getIsActive()).isTrue();
    }

    @Test
    void lockingAUserDeactivatesAndSignsThemOut() {
        Report report = pending(ReportTargetType.USER, OWNER);
        when(reportRepository.findById(5L)).thenReturn(Optional.of(report));
        when(reportRepository.findByTargetTypeAndTargetIdAndTargetKeyAndStatus(any(), anyLong(), any(), any()))
                .thenReturn(List.of(report));

        service.resolve(5L, ACTOR, true, new ResolveReportRequest(ReportAction.LOCK_USER, "spam liên tục", null));

        assertThat(owner.getIsActive()).isFalse();
        verify(refreshTokenService).revokeAll(OWNER);
    }

    @Test
    void staffAccountsCannotBeLockedThroughAReport() {
        owner.setRole(UserRole.MODERATOR);
        Report report = pending(ReportTargetType.USER, OWNER);
        when(reportRepository.findById(5L)).thenReturn(Optional.of(report));

        assertThatThrownBy(() -> service.resolve(5L, ACTOR, true,
                new ResolveReportRequest(ReportAction.LOCK_USER, null, null)))
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
        when(reportRepository.findByTargetTypeAndTargetIdAndTargetKeyAndStatus(any(), anyLong(), any(), any()))
                .thenReturn(List.of(report));

        service.dismiss(5L, ACTOR, "  không vi phạm ");

        assertThat(report.getStatus()).isEqualTo(ReportStatus.DISMISSED);
        assertThat(report.getAction()).isNull();
        assertThat(report.getResolutionNote()).isEqualTo("không vi phạm");
        verify(videoService, never()).rejectVideo(anyLong(), anyLong(), any());
    }
}
