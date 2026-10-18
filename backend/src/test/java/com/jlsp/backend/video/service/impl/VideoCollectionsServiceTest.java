package com.jlsp.backend.video.service.impl;

import com.jlsp.backend.common.response.PageResponse;
import com.jlsp.backend.user.entity.User;
import com.jlsp.backend.user.repository.FollowRepository;
import com.jlsp.backend.user.repository.UserRepository;
import com.jlsp.backend.video.dto.response.VideoResponse;
import com.jlsp.backend.video.entity.Video;
import com.jlsp.backend.video.mapper.VideoMapper;
import com.jlsp.backend.video.repository.ShadowingPracticeRepository;
import com.jlsp.backend.video.repository.VideoLikeRepository;
import com.jlsp.backend.video.repository.VideoRepository;
import com.jlsp.backend.video.repository.VideoSaveRepository;
import org.junit.jupiter.api.Test;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/** Danh sách video đã lưu / đã thích: cờ isLiked/isSaved lấy bằng truy vấn gộp, không N+1. */
class VideoCollectionsServiceTest {

    private final VideoLikeRepository likes = mock(VideoLikeRepository.class);
    private final VideoSaveRepository saves = mock(VideoSaveRepository.class);
    private final VideoServiceImpl service = new VideoServiceImpl(
            mock(VideoRepository.class), likes, saves, mock(ShadowingPracticeRepository.class),
            mock(UserRepository.class), mock(FollowRepository.class), new VideoMapper());

    private static Video video(long id) {
        User creator = new User();
        creator.setId(9L);
        creator.setUsername("tanaka");
        Video v = new Video();
        v.setId(id);
        v.setTitle("Video " + id);
        v.setUser(creator);
        return v;
    }

    @Test
    void savedVideosCarryViewerLikeAndSaveFlags() {
        PageRequest pageable = PageRequest.of(0, 30);
        when(saves.findVideosByUserId(42L, pageable)).thenReturn(new PageImpl<>(List.of(video(1), video(2)), pageable, 2));
        when(likes.findVideoIdsByUserIdAndVideoIdIn(42L, List.of(1L, 2L))).thenReturn(List.of(2L));
        when(saves.findVideoIdsByUserIdAndVideoIdIn(42L, List.of(1L, 2L))).thenReturn(List.of(1L, 2L));

        PageResponse<VideoResponse> page = service.getSavedVideos(42L, pageable);

        assertThat(page.getContent()).extracting(VideoResponse::getId).containsExactly(1L, 2L);
        assertThat(page.getContent()).extracting(VideoResponse::getIsSaved).containsExactly(true, true);
        assertThat(page.getContent()).extracting(VideoResponse::getIsLiked).containsExactly(false, true);
        assertThat(page.getTotalElements()).isEqualTo(2);
        verify(likes, never()).existsByIdUserIdAndIdVideoId(anyLong(), anyLong());
    }

    @Test
    void emptyLikedListSkipsFlagQueries() {
        PageRequest pageable = PageRequest.of(0, 30);
        when(likes.findVideosByUserId(42L, pageable)).thenReturn(new PageImpl<>(List.of(), pageable, 0));

        PageResponse<VideoResponse> page = service.getLikedVideos(42L, pageable);

        assertThat(page.getContent()).isEmpty();
        verify(likes, never()).findVideoIdsByUserIdAndVideoIdIn(anyLong(), org.mockito.ArgumentMatchers.anyCollection());
    }
}
