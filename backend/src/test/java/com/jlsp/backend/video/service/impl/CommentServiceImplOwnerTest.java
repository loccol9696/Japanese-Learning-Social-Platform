package com.jlsp.backend.video.service.impl;

import com.jlsp.backend.block.service.BlockService;
import com.jlsp.backend.common.exception.AppException;
import com.jlsp.backend.common.repository.IdCount;
import com.jlsp.backend.notification.service.NotificationService;
import com.jlsp.backend.report.entity.ReportTargetType;
import com.jlsp.backend.report.repository.ReportRepository;
import com.jlsp.backend.user.entity.User;
import com.jlsp.backend.user.repository.UserRepository;
import com.jlsp.backend.video.dto.request.CommentSort;
import com.jlsp.backend.video.dto.response.CommentFlagsResponse;
import com.jlsp.backend.video.dto.response.VideoCommentResponse;
import com.jlsp.backend.video.entity.Video;
import com.jlsp.backend.video.entity.VideoComment;
import com.jlsp.backend.video.repository.CommentLikeRepository;
import com.jlsp.backend.video.repository.VideoCommentRepository;
import com.jlsp.backend.video.repository.VideoRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.time.LocalDateTime;
import java.util.Collection;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class CommentServiceImplOwnerTest {

    private static final long OWNER = 1L;
    private static final long OTHER = 2L;
    private static final long VIDEO_ID = 7L;

    private VideoCommentRepository commentRepository;
    private ReportRepository reportRepository;
    private CommentServiceImpl service;
    private NotificationService notificationService;
    private User owner;
    private User other;
    private Video video;

    @BeforeEach
    void setUp() {
        commentRepository = mock(VideoCommentRepository.class);
        reportRepository = mock(ReportRepository.class);
        VideoRepository videoRepository = mock(VideoRepository.class);
        BlockService blockService = mock(BlockService.class);
        when(blockService.relatedUserIds(any())).thenReturn(java.util.Set.of());
        notificationService = mock(NotificationService.class);
        service = new CommentServiceImpl(commentRepository, mock(CommentLikeRepository.class), videoRepository,
                mock(UserRepository.class), blockService, notificationService, reportRepository);

        owner = User.builder().id(OWNER).username("owner").build();
        other = User.builder().id(OTHER).username("hana").build();
        video = Video.builder().id(VIDEO_ID).user(owner).build();
        when(videoRepository.existsById(VIDEO_ID)).thenReturn(true);
    }

    private VideoComment comment(long id, User author, VideoComment parent) {
        VideoComment c = VideoComment.builder().id(id).video(video).user(author).parent(parent)
                .content("Cảm ơn bạn, mình đã hiểu cách dùng ngữ pháp này rồi").likeCount(0)
                .createdAt(LocalDateTime.now().minusDays(1)).build();
        when(commentRepository.findById(id)).thenReturn(Optional.of(c));
        return c;
    }

    @Test
    void chiChuVideoMoiGhimDuoc() {
        comment(10, other, null);

        assertThatThrownBy(() -> service.pin(VIDEO_ID, 10L, OTHER))
                .isInstanceOfSatisfying(AppException.class, e -> assertThat(e.getStatus()).isEqualTo(403));
        verify(commentRepository, never()).clearPinned(anyLong());
    }

    @Test
    void ghimBinhLuanMoiBoGhimBinhLuanCu() {
        VideoComment c = comment(10, other, null);

        CommentFlagsResponse result = service.pin(VIDEO_ID, 10L, OWNER);

        verify(commentRepository).clearPinned(VIDEO_ID);
        assertThat(c.isPinned()).isTrue();
        assertThat(result.pinned()).isTrue();
    }

    @Test
    void ghimLaiBinhLuanDangGhimKhongBoGhimNo() {
        VideoComment c = comment(10, other, null);
        c.setPinned(true);

        service.pin(VIDEO_ID, 10L, OWNER);

        verify(commentRepository, never()).clearPinned(anyLong());
        assertThat(c.isPinned()).isTrue();
    }

    @Test
    void khongGhimDuocPhanHoi() {
        VideoComment parent = comment(10, other, null);
        comment(11, other, parent);

        assertThatThrownBy(() -> service.pin(VIDEO_ID, 11L, OWNER))
                .isInstanceOfSatisfying(AppException.class, e -> assertThat(e.getStatus()).isEqualTo(400));
    }

    @Test
    void boGhimDatCoVeFalse() {
        VideoComment c = comment(10, other, null);
        c.setPinned(true);

        assertThat(service.unpin(VIDEO_ID, 10L, OWNER).pinned()).isFalse();
        assertThat(c.isPinned()).isFalse();
    }

    @Test
    void binhLuanDuocGhimLuonNamDauCaHaiCachSapXep() {
        VideoComment a = comment(10, other, null);
        VideoComment pinned = comment(11, other, null);
        pinned.setPinned(true);
        VideoComment c = comment(12, other, null);
        for (CommentSort sort : CommentSort.values()) {
            when(commentRepository.findByVideoIdAndParentIsNull(VIDEO_ID, sort.getOrder()))
                    .thenReturn(List.of(a, c, pinned));
        }

        for (CommentSort sort : CommentSort.values()) {
            List<VideoCommentResponse> result = service.list(VIDEO_ID, null, sort);
            assertThat(result.get(0).getId()).isEqualTo(11L);
            assertThat(result.get(0).getPinned()).isTrue();
        }
    }

    @Test
    void sapHuuIchTruBinhLuanDangBiBaoCao() {
        VideoComment bi = comment(10, other, null);
        bi.setLikeCount(8);
        VideoComment sach = comment(11, other, null);
        sach.setLikeCount(3);
        when(commentRepository.findByVideoIdAndParentIsNull(VIDEO_ID, CommentSort.HELPFUL.getOrder()))
                .thenReturn(List.of(bi, sach));
        when(reportRepository.countPendingByTargetIds(eq(ReportTargetType.COMMENT), any(Collection.class)))
                .thenReturn(List.of(idCount(10L, 2L)));

        List<VideoCommentResponse> result = service.list(VIDEO_ID, null, CommentSort.HELPFUL);

        assertThat(result).extracting(VideoCommentResponse::getId).containsExactly(11L, 10L);
    }

    private static IdCount idCount(Long id, Long total) {
        return new IdCount() {
            @Override
            public Long getId() {
                return id;
            }

            @Override
            public Long getTotal() {
                return total;
            }
        };
    }
}
