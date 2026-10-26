package com.jlsp.backend.video.service.impl;

import com.jlsp.backend.block.service.BlockService;
import com.jlsp.backend.common.exception.AppException;
import com.jlsp.backend.notification.service.NotificationService;
import com.jlsp.backend.user.entity.User;
import com.jlsp.backend.user.repository.UserRepository;
import com.jlsp.backend.video.dto.request.CreateCommentRequest;
import com.jlsp.backend.video.dto.response.VideoCommentResponse;
import com.jlsp.backend.video.entity.Video;
import com.jlsp.backend.video.entity.VideoComment;
import com.jlsp.backend.video.repository.VideoCommentRepository;
import com.jlsp.backend.video.repository.VideoRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Optional;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class CommentServiceImplBlockTest {

    private static final long VIDEO_ID = 10L;
    private static final long VIEWER = 1L;
    private static final long OWNER = 2L;
    private static final long BLOCKED = 3L;
    private static final long FRIEND = 4L;

    private VideoCommentRepository commentRepository;
    private VideoRepository videoRepository;
    private UserRepository userRepository;
    private BlockService blockService;
    private CommentServiceImpl service;

    private Video video;

    @BeforeEach
    void setUp() {
        commentRepository = mock(VideoCommentRepository.class);
        videoRepository = mock(VideoRepository.class);
        userRepository = mock(UserRepository.class);
        blockService = mock(BlockService.class);
        service = new CommentServiceImpl(commentRepository, videoRepository, userRepository,
                blockService, mock(NotificationService.class));

        User owner = User.builder().id(OWNER).username("owner").build();
        video = Video.builder().id(VIDEO_ID).user(owner).build();
        when(videoRepository.findById(VIDEO_ID)).thenReturn(Optional.of(video));
        when(videoRepository.existsById(VIDEO_ID)).thenReturn(true);
    }

    private VideoComment comment(long id, long authorId, String text) {
        User author = User.builder().id(authorId).username("u" + authorId).build();
        return VideoComment.builder().id(id).video(video).user(author).content(text).build();
    }

    @Test
    void cannotCommentOnTheVideoOfSomeoneWithABlockBetweenYou() {
        when(userRepository.findById(VIEWER)).thenReturn(Optional.of(User.builder().id(VIEWER).build()));
        when(blockService.isBlockedEitherWay(VIEWER, OWNER)).thenReturn(true);
        CreateCommentRequest request = new CreateCommentRequest();
        request.setContent("xin chào");

        assertThatThrownBy(() -> service.create(VIDEO_ID, VIEWER, request))
                .isInstanceOfSatisfying(AppException.class, e -> assertThat(e.getStatus()).isEqualTo(403));
        verify(commentRepository, never()).save(any());
    }

    @Test
    void hidesCommentsAndRepliesOfBlockedPeopleFromTheViewer() {
        VideoComment visible = comment(1L, FRIEND, "bình thường");
        VideoComment hiddenTop = comment(2L, BLOCKED, "người bị chặn");
        VideoComment hiddenReply = comment(3L, BLOCKED, "trả lời từ người bị chặn");
        VideoComment shownReply = comment(4L, OWNER, "trả lời hợp lệ");
        when(blockService.relatedUserIds(VIEWER)).thenReturn(Set.of(BLOCKED));
        when(commentRepository.findByVideoIdAndParentIsNullOrderByCreatedAtDesc(VIDEO_ID))
                .thenReturn(List.of(visible, hiddenTop));
        when(commentRepository.findByParentIdOrderByCreatedAtAsc(1L))
                .thenReturn(List.of(hiddenReply, shownReply));

        List<VideoCommentResponse> result = service.list(VIDEO_ID, VIEWER);

        assertThat(result).extracting(VideoCommentResponse::getContent).containsExactly("bình thường");
        assertThat(result.get(0).getReplies()).extracting(VideoCommentResponse::getContent)
                .containsExactly("trả lời hợp lệ");
    }

    @Test
    void guestsSeeEveryComment() {
        VideoComment top = comment(1L, BLOCKED, "ai cũng thấy");
        when(blockService.relatedUserIds(null)).thenReturn(Set.of());
        when(commentRepository.findByVideoIdAndParentIsNullOrderByCreatedAtDesc(VIDEO_ID))
                .thenReturn(List.of(top));

        assertThat(service.list(VIDEO_ID, null)).hasSize(1);
    }
}
