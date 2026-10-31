package com.jlsp.backend.video.service.impl;

import com.jlsp.backend.common.exception.AppException;
import com.jlsp.backend.common.exception.ResourceNotFoundException;
import com.jlsp.backend.user.entity.User;
import com.jlsp.backend.user.repository.UserRepository;
import com.jlsp.backend.video.dto.request.CommentSort;
import com.jlsp.backend.video.dto.response.CommentLikeResponse;
import com.jlsp.backend.video.dto.response.VideoCommentResponse;
import com.jlsp.backend.video.entity.Video;
import com.jlsp.backend.video.entity.VideoComment;
import com.jlsp.backend.video.repository.CommentLikeRepository;
import com.jlsp.backend.video.repository.VideoCommentRepository;
import com.jlsp.backend.video.repository.VideoRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.data.domain.Sort;

import java.util.List;
import java.util.Optional;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class CommentServiceImplLikeTest {

    private static final long AUTHOR = 1L;
    private static final long VIEWER = 2L;
    private static final long VIDEO = 7L;
    private static final long COMMENT = 9L;

    private VideoCommentRepository commentRepository;
    private CommentLikeRepository commentLikeRepository;
    private CommentServiceImpl service;
    private Video video;
    private User author;

    @BeforeEach
    void setUp() {
        commentRepository = mock(VideoCommentRepository.class);
        commentLikeRepository = mock(CommentLikeRepository.class);
        VideoRepository videoRepository = mock(VideoRepository.class);
        service = new CommentServiceImpl(commentRepository, commentLikeRepository, videoRepository,
                mock(UserRepository.class));

        video = Video.builder().id(VIDEO).build();
        author = User.builder().id(AUTHOR).username("hana").build();
        when(videoRepository.existsById(VIDEO)).thenReturn(true);
        when(commentRepository.findById(COMMENT)).thenReturn(Optional.of(comment(COMMENT, null)));
        when(commentRepository.findLikeCountById(COMMENT)).thenReturn(4);
    }

    @Test
    void likeCountsOnlyTheFirstTime() {
        when(commentLikeRepository.insertIfAbsent(eq(VIEWER), eq(COMMENT), any())).thenReturn(1, 0);

        CommentLikeResponse first = service.like(VIDEO, COMMENT, VIEWER);
        CommentLikeResponse repeat = service.like(VIDEO, COMMENT, VIEWER);

        verify(commentRepository).updateLikeCount(COMMENT, 1);
        assertThat(first.getIsLiked()).isTrue();
        assertThat(repeat.getIsLiked()).isTrue();
        assertThat(repeat.getLikeCount()).isEqualTo(4);
    }

    @Test
    void unlikeCountsOnlyWhenALikeExisted() {
        when(commentLikeRepository.deleteLike(VIEWER, COMMENT)).thenReturn(1, 0);

        CommentLikeResponse first = service.unlike(VIDEO, COMMENT, VIEWER);
        service.unlike(VIDEO, COMMENT, VIEWER);

        verify(commentRepository).updateLikeCount(COMMENT, -1);
        assertThat(first.getIsLiked()).isFalse();
    }

    @Test
    void authorCannotLikeOwnComment() {
        assertThatThrownBy(() -> service.like(VIDEO, COMMENT, AUTHOR))
                .isInstanceOfSatisfying(AppException.class, e -> assertThat(e.getMessage()).contains("tự đánh giá"));

        verify(commentLikeRepository, never()).insertIfAbsent(anyLong(), anyLong(), any());
        verify(commentRepository, never()).updateLikeCount(anyLong(), anyInt());
    }

    @Test
    void likingCommentThroughAnotherVideoIsNotFound() {
        assertThatThrownBy(() -> service.like(VIDEO + 1, COMMENT, VIEWER))
                .isInstanceOf(ResourceNotFoundException.class);
        assertThatThrownBy(() -> service.unlike(VIDEO + 1, COMMENT, VIEWER))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void helpfulSortRanksByLikesThenNewest() {
        Sort sort = CommentSort.HELPFUL.getOrder();

        assertThat(sort.stream().map(Sort.Order::getProperty)).containsExactly("likeCount", "createdAt", "id");
        assertThat(sort.stream().allMatch(Sort.Order::isDescending)).isTrue();
    }

    @Test
    void listMarksViewerLikesOnCommentsAndReplies() {
        VideoComment root = comment(COMMENT, null);
        VideoComment likedReply = comment(10L, root);
        VideoComment otherReply = comment(11L, root);
        when(commentRepository.findByVideoIdAndParentIsNull(VIDEO, CommentSort.NEWEST.getOrder()))
                .thenReturn(List.of(root));
        when(commentRepository.findByVideoIdAndParentIsNotNullOrderByCreatedAtAsc(VIDEO))
                .thenReturn(List.of(likedReply, otherReply));
        when(commentLikeRepository.findLikedCommentIds(VIEWER, VIDEO)).thenReturn(Set.of(10L));

        VideoCommentResponse response = service.list(VIDEO, VIEWER, CommentSort.NEWEST).get(0);

        assertThat(response.getIsLiked()).isFalse();
        assertThat(response.getReplies()).extracting(VideoCommentResponse::getId).containsExactly(10L, 11L);
        assertThat(response.getReplies()).extracting(VideoCommentResponse::getIsLiked).containsExactly(true, false);
    }

    @Test
    void guestListSkipsLikeLookup() {
        when(commentRepository.findByVideoIdAndParentIsNull(VIDEO, CommentSort.HELPFUL.getOrder()))
                .thenReturn(List.of(comment(COMMENT, null)));

        VideoCommentResponse response = service.list(VIDEO, null, CommentSort.HELPFUL).get(0);

        assertThat(response.getIsLiked()).isFalse();
        verify(commentLikeRepository, never()).findLikedCommentIds(any(), any());
    }

    private VideoComment comment(long id, VideoComment parent) {
        return VideoComment.builder().id(id).video(video).user(author).parent(parent).content("hay").build();
    }
}
