package com.jlsp.backend.video.service.impl;

import com.jlsp.backend.block.service.BlockService;
import com.jlsp.backend.notification.service.NotificationService;
import com.jlsp.backend.topic.service.TopicService;
import com.jlsp.backend.user.entity.JLPTLevel;
import com.jlsp.backend.user.entity.User;
import com.jlsp.backend.user.entity.UserRole;
import com.jlsp.backend.user.repository.FollowRepository;
import com.jlsp.backend.user.repository.UserRepository;
import com.jlsp.backend.video.dto.request.UpdateVideoRequest;
import com.jlsp.backend.video.entity.Video;
import com.jlsp.backend.video.entity.VideoModStatus;
import com.jlsp.backend.video.entity.VideoStatus;
import com.jlsp.backend.video.mapper.VideoMapper;
import com.jlsp.backend.video.repository.ShadowingPracticeRepository;
import com.jlsp.backend.video.repository.VideoCommentRepository;
import com.jlsp.backend.video.repository.VideoLikeRepository;
import com.jlsp.backend.video.repository.VideoRepository;
import com.jlsp.backend.video.repository.VideoSaveRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.time.LocalDateTime;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

/** Sửa video: nội dung hiển thị đổi thì video công khai phải được kiểm duyệt lại. */
class VideoServiceImplUpdateTest {

    private static final long OWNER = 5L;
    private static final long VIDEO_ID = 10L;

    private VideoRepository videoRepository;
    private VideoServiceImpl service;
    private Video video;

    @BeforeEach
    void setUp() {
        videoRepository = mock(VideoRepository.class);
        UserRepository userRepository = mock(UserRepository.class);
        service = new VideoServiceImpl(videoRepository, mock(VideoLikeRepository.class),
                mock(VideoSaveRepository.class), mock(VideoCommentRepository.class),
                mock(ShadowingPracticeRepository.class), userRepository, mock(FollowRepository.class),
                new VideoMapper(), mock(TopicService.class), mock(NotificationService.class),
                mock(BlockService.class));

        User owner = User.builder().id(OWNER).username("owner").role(UserRole.USER).build();
        video = Video.builder().id(VIDEO_ID).user(owner).title("Bài 1").description("Mô tả")
                .thumbnailUrl("https://cdn/thumb.jpg").jlptLevel(JLPTLevel.N5)
                .status(VideoStatus.PUBLIC).modStatus(VideoModStatus.APPROVED)
                .moderatedBy(99L).moderatedAt(LocalDateTime.now()).build();

        when(userRepository.findById(OWNER)).thenReturn(Optional.of(owner));
        when(videoRepository.findById(VIDEO_ID)).thenReturn(Optional.of(video));
        when(videoRepository.save(any(Video.class))).thenAnswer(inv -> inv.getArgument(0));
    }

    private UpdateVideoRequest request() {
        return new UpdateVideoRequest();
    }

    @Test
    void changingTheTitleOfAnApprovedVideoSendsItBackToReview() {
        UpdateVideoRequest request = request();
        request.setTitle("Tiêu đề mới");

        service.updateVideo(VIDEO_ID, OWNER, request);

        assertThat(video.getModStatus()).isEqualTo(VideoModStatus.PENDING);
        assertThat(video.getModeratedBy()).isNull();
        assertThat(video.getModeratedAt()).isNull();
    }

    @Test
    void editingARejectedVideoResubmitsItForReview() {
        video.setModStatus(VideoModStatus.REJECTED);
        video.setRejectionReason("Vi phạm");
        UpdateVideoRequest request = request();
        request.setDescription("Đã sửa lại mô tả");

        service.updateVideo(VIDEO_ID, OWNER, request);

        assertThat(video.getModStatus()).isEqualTo(VideoModStatus.PENDING);
        assertThat(video.getRejectionReason()).isNull();
    }

    @Test
    void changingTheThumbnailAlsoRequiresReview() {
        UpdateVideoRequest request = request();
        request.setThumbnailUrl("https://cdn/new.jpg");

        service.updateVideo(VIDEO_ID, OWNER, request);

        assertThat(video.getModStatus()).isEqualTo(VideoModStatus.PENDING);
    }

    @Test
    void resendingTheSameContentDoesNotTriggerAReview() {
        UpdateVideoRequest request = request();
        request.setTitle("  Bài 1 ");
        request.setDescription("Mô tả");
        request.setThumbnailUrl("https://cdn/thumb.jpg");

        service.updateVideo(VIDEO_ID, OWNER, request);

        assertThat(video.getModStatus()).isEqualTo(VideoModStatus.APPROVED);
        assertThat(video.getModeratedBy()).isEqualTo(99L);
    }

    @Test
    void emptyDescriptionCountsAsNoDescription() {
        video.setDescription(null);
        UpdateVideoRequest request = request();
        request.setDescription("");

        service.updateVideo(VIDEO_ID, OWNER, request);

        assertThat(video.getModStatus()).isEqualTo(VideoModStatus.APPROVED);
    }

    @Test
    void changingOnlyTheLevelDoesNotTriggerAReview() {
        UpdateVideoRequest request = request();
        request.setJlptLevel(JLPTLevel.N3);

        service.updateVideo(VIDEO_ID, OWNER, request);

        assertThat(video.getJlptLevel()).isEqualTo(JLPTLevel.N3);
        assertThat(video.getModStatus()).isEqualTo(VideoModStatus.APPROVED);
    }

    @Test
    void privateVideosAreNotReviewedWhenEdited() {
        video.setStatus(VideoStatus.PRIVATE);
        UpdateVideoRequest request = request();
        request.setTitle("Ghi chú riêng tư mới");

        service.updateVideo(VIDEO_ID, OWNER, request);

        assertThat(video.getModStatus()).isEqualTo(VideoModStatus.APPROVED);
    }

    @Test
    void aVideoThatIsStillPendingStaysPending() {
        video.setModStatus(VideoModStatus.PENDING);
        UpdateVideoRequest request = request();
        request.setTitle("Tiêu đề khác");

        service.updateVideo(VIDEO_ID, OWNER, request);

        assertThat(video.getModStatus()).isEqualTo(VideoModStatus.PENDING);
    }
}
