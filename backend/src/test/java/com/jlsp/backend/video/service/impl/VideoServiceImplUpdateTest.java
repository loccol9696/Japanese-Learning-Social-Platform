package com.jlsp.backend.video.service.impl;

import com.jlsp.backend.block.service.BlockService;
import com.jlsp.backend.common.exception.AppException;
import com.jlsp.backend.notification.service.NotificationService;
import com.jlsp.backend.topic.entity.Topic;
import com.jlsp.backend.topic.service.TopicService;
import com.jlsp.backend.user.entity.JLPTLevel;
import com.jlsp.backend.user.entity.User;
import com.jlsp.backend.user.entity.UserRole;
import com.jlsp.backend.user.repository.FollowRepository;
import com.jlsp.backend.user.repository.UserRepository;
import com.jlsp.backend.video.dto.request.UpdateVideoClassificationRequest;
import com.jlsp.backend.video.dto.request.UpdateVideoRequest;
import com.jlsp.backend.video.entity.Hashtag;
import com.jlsp.backend.video.entity.Video;
import com.jlsp.backend.video.entity.VideoModStatus;
import com.jlsp.backend.video.entity.VideoStatus;
import com.jlsp.backend.video.mapper.VideoMapper;
import com.jlsp.backend.video.repository.ShadowingPracticeRepository;
import com.jlsp.backend.video.repository.VideoCommentRepository;
import com.jlsp.backend.video.repository.VideoLikeRepository;
import com.jlsp.backend.video.repository.VideoRepository;
import com.jlsp.backend.video.repository.VideoSaveRepository;
import com.jlsp.backend.video.service.HashtagService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.time.LocalDateTime;
import java.util.HashSet;
import java.util.List;
import java.util.Optional;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

/** Sửa video: nội dung hiển thị đổi thì video công khai phải được kiểm duyệt lại. */
class VideoServiceImplUpdateTest {

    private static final long OWNER = 5L;
    private static final long VIDEO_ID = 10L;

    private VideoRepository videoRepository;
    private TopicService topicService;
    private HashtagService hashtagService;
    private VideoServiceImpl service;
    private Video video;

    @BeforeEach
    void setUp() {
        videoRepository = mock(VideoRepository.class);
        UserRepository userRepository = mock(UserRepository.class);
        topicService = mock(TopicService.class);
        hashtagService = mock(HashtagService.class);
        service = new VideoServiceImpl(videoRepository, mock(VideoLikeRepository.class),
                mock(VideoSaveRepository.class), mock(VideoCommentRepository.class),
                mock(ShadowingPracticeRepository.class), userRepository, mock(FollowRepository.class),
                new VideoMapper(), topicService, hashtagService, mock(NotificationService.class),
                mock(BlockService.class), mock(com.jlsp.backend.common.security.ratelimit.RateLimiter.class),
                mock(org.springframework.context.ApplicationEventPublisher.class));

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
    void changingHashtagsDoesNotTriggerAReview() {
        when(hashtagService.resolve(List.of("anime"))).thenReturn(hashtags("anime"));
        UpdateVideoRequest request = request();
        request.setHashtags(List.of("anime"));

        service.updateVideo(VIDEO_ID, OWNER, request);

        assertThat(video.getHashtags()).extracting(Hashtag::getName).containsExactly("anime");
        assertThat(video.getModStatus()).isEqualTo(VideoModStatus.APPROVED);
    }

    @Test
    void addingTopicsToAnExistingVideoDoesNotTriggerAReview() {
        when(topicService.requireActive(Set.of(1L, 2L))).thenReturn(new HashSet<>(Set.of(topic(1L), topic(2L))));
        UpdateVideoRequest request = request();
        request.setTopicIds(Set.of(1L, 2L));

        service.updateVideo(VIDEO_ID, OWNER, request);

        assertThat(video.getTopics()).extracting(Topic::getId).containsExactlyInAnyOrder(1L, 2L);
        assertThat(video.getModStatus()).isEqualTo(VideoModStatus.APPROVED);
    }

    @Test
    void anEmptyTopicListClearsTheTopics() {
        video.setTopics(new HashSet<>(Set.of(topic(1L))));
        when(topicService.requireActive(Set.of())).thenReturn(new HashSet<>());
        UpdateVideoRequest request = request();
        request.setTopicIds(Set.of());

        service.updateVideo(VIDEO_ID, OWNER, request);

        assertThat(video.getTopics()).isEmpty();
    }

    @Test
    void leavingTopicsOutKeepsThemUnchanged() {
        video.setTopics(new HashSet<>(Set.of(topic(1L))));
        UpdateVideoRequest request = request();
        request.setTitle("Bài 1");

        service.updateVideo(VIDEO_ID, OWNER, request);

        assertThat(video.getTopics()).extracting(Topic::getId).containsExactly(1L);
    }

    @Test
    void moreThanThreeTopicsAreRejected() {
        UpdateVideoRequest request = request();
        request.setTopicIds(Set.of(1L, 2L, 3L, 4L));

        assertThatThrownBy(() -> service.updateVideo(VIDEO_ID, OWNER, request))
                .isInstanceOf(AppException.class);
    }

    @Test
    void aTopicAlreadyOnTheVideoIsKeptEvenIfAdminHidItLater() {
        Topic hidden = topic(1L);
        hidden.setIsActive(false);
        video.setTopics(new HashSet<>(Set.of(hidden)));
        when(topicService.requireActive(Set.of(2L))).thenReturn(new HashSet<>(Set.of(topic(2L))));
        UpdateVideoRequest request = request();
        request.setTopicIds(Set.of(1L, 2L));

        service.updateVideo(VIDEO_ID, OWNER, request);

        assertThat(video.getTopics()).extracting(Topic::getId).containsExactlyInAnyOrder(1L, 2L);
    }

    @Test
    void moderatorChangingTheClassificationKeepsTheVideoApproved() {
        when(topicService.requireActive(Set.of(2L))).thenReturn(new HashSet<>(Set.of(topic(2L))));
        when(hashtagService.resolve(List.of("n5"))).thenReturn(hashtags("n5"));

        service.updateClassification(VIDEO_ID, UpdateVideoClassificationRequest.builder()
                .topicIds(Set.of(2L)).hashtags(List.of("n5")).build());

        assertThat(video.getTopics()).extracting(Topic::getId).containsExactly(2L);
        assertThat(video.getHashtags()).extracting(Hashtag::getName).containsExactly("n5");
        assertThat(video.getModStatus()).isEqualTo(VideoModStatus.APPROVED);
    }

    private static Topic topic(long id) {
        return Topic.builder().id(id).name("Chủ đề " + id).sortOrder((int) id).build();
    }

    private static Set<Hashtag> hashtags(String name) {
        return new HashSet<>(Set.of(Hashtag.builder().name(name).build()));
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
