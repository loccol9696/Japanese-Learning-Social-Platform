package com.jlsp.backend.user.service;

import com.jlsp.backend.common.exception.AppException;
import com.jlsp.backend.user.dto.response.FollowResultResponse;
import com.jlsp.backend.user.dto.response.PublicProfileResponse;
import com.jlsp.backend.user.entity.Follow;
import com.jlsp.backend.user.entity.FollowId;
import com.jlsp.backend.user.entity.User;
import com.jlsp.backend.user.repository.FollowRepository;
import com.jlsp.backend.user.repository.UserRepository;
import com.jlsp.backend.video.repository.VideoRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class PublicProfileServiceTest {

    private UserRepository users;
    private FollowRepository follows;
    private VideoRepository videos;
    private PublicProfileService service;

    @BeforeEach
    void setUp() {
        users = mock(UserRepository.class);
        follows = mock(FollowRepository.class);
        videos = mock(VideoRepository.class);
        service = new PublicProfileService(users, follows, videos);

        User yuuka = User.builder().id(2L).username("yuukachan").email("secret@x.com").displayName("Yuuka")
                .isActive(true).build();
        when(users.findById(2L)).thenReturn(Optional.of(yuuka));
        when(users.findById(1L)).thenReturn(Optional.of(User.builder().id(1L).username("me").isActive(true).build()));
        when(follows.countByIdFollowingId(2L)).thenReturn(1200L);
        when(follows.countByIdFollowerId(2L)).thenReturn(38L);
        when(videos.sumLikesByUserId(2L)).thenReturn(14000L);
        when(videos.countByUserId(2L)).thenReturn(6L);
    }

    @Test
    void publicProfileHasStatsAndNoEmail() {
        PublicProfileResponse p = service.getPublicProfile(2L, null);

        assertThat(p.getUsername()).isEqualTo("yuukachan");
        assertThat(p.getDisplayName()).isEqualTo("Yuuka");
        assertThat(p.getFollowersCount()).isEqualTo(1200);
        assertThat(p.getFollowingCount()).isEqualTo(38);
        assertThat(p.getLikesCount()).isEqualTo(14000);
        assertThat(p.getVideosCount()).isEqualTo(6);
        assertThat(p.isFollowing()).isFalse();
        assertThat(p.isSelf()).isFalse();
        assertThat(PublicProfileResponse.class.getDeclaredFields())
                .noneMatch(f -> f.getName().toLowerCase().contains("email"));
    }

    @Test
    void profileShowsWhetherTheViewerFollows() {
        when(follows.existsByIdFollowerIdAndIdFollowingId(1L, 2L)).thenReturn(true);
        assertThat(service.getPublicProfile(2L, 1L).isFollowing()).isTrue();
    }

    @Test
    void viewingYourOwnProfileIsFlaggedAndNeverFollowing() {
        PublicProfileResponse p = service.getPublicProfile(2L, 2L);
        assertThat(p.isSelf()).isTrue();
        assertThat(p.isFollowing()).isFalse();
    }

    @Test
    void inactiveOrMissingUsersAreNotFound() {
        when(users.findById(3L)).thenReturn(Optional.of(User.builder().id(3L).isActive(false).build()));
        assertThatThrownBy(() -> service.getPublicProfile(3L, null)).isInstanceOf(AppException.class);
        assertThatThrownBy(() -> service.getPublicProfile(99L, null)).isInstanceOf(AppException.class);
    }

    @Test
    void firstToggleFollowsAndSecondUnfollows() {
        FollowId id = new FollowId(1L, 2L);
        when(follows.existsById(id)).thenReturn(false);
        when(follows.countByIdFollowingId(2L)).thenReturn(1201L);

        FollowResultResponse r = service.toggleFollow(1L, 2L);
        assertThat(r.isFollowing()).isTrue();
        assertThat(r.getFollowersCount()).isEqualTo(1201);
        verify(follows).save(any(Follow.class));

        when(follows.existsById(id)).thenReturn(true);
        when(follows.countByIdFollowingId(2L)).thenReturn(1200L);
        FollowResultResponse r2 = service.toggleFollow(1L, 2L);
        assertThat(r2.isFollowing()).isFalse();
        verify(follows).deleteById(id);
    }

    @Test
    void cannotFollowYourself() {
        assertThatThrownBy(() -> service.toggleFollow(2L, 2L))
                .isInstanceOf(AppException.class).hasMessageContaining("chính mình");
        verify(follows, never()).save(any());
    }
}
