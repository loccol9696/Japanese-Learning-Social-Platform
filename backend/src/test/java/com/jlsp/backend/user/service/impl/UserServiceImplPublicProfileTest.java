package com.jlsp.backend.user.service.impl;

import com.jlsp.backend.common.exception.AppException;
import com.jlsp.backend.common.security.token.RefreshTokenService;
import com.jlsp.backend.user.dto.response.PublicProfileResponse;
import com.jlsp.backend.user.entity.User;
import com.jlsp.backend.user.mapper.UserMapper;
import com.jlsp.backend.user.repository.FollowRepository;
import com.jlsp.backend.user.repository.UserRepository;
import com.jlsp.backend.video.repository.VideoRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class UserServiceImplPublicProfileTest {

    private static final long VIEWER = 1L;
    private static final long OWNER = 2L;

    private UserRepository userRepository;
    private FollowRepository followRepository;
    private VideoRepository videoRepository;
    private UserServiceImpl service;

    @BeforeEach
    void setUp() {
        userRepository = mock(UserRepository.class);
        followRepository = mock(FollowRepository.class);
        videoRepository = mock(VideoRepository.class);
        service = new UserServiceImpl(userRepository, new UserMapper(), mock(PasswordEncoder.class),
                followRepository, videoRepository, mock(RefreshTokenService.class),
                mock(com.jlsp.backend.topic.service.TopicService.class));

        when(followRepository.countByIdFollowerId(OWNER)).thenReturn(3L);
        when(followRepository.countByIdFollowingId(OWNER)).thenReturn(5L);
        when(videoRepository.sumLikesByUserId(OWNER)).thenReturn(11L);
        when(videoRepository.countByUserId(OWNER)).thenReturn(4L);
    }

    @Test
    void showsStatsAndTheRelationWithTheViewer() {
        when(userRepository.findById(OWNER)).thenReturn(Optional.of(owner(true)));
        when(followRepository.existsByIdFollowerIdAndIdFollowingId(VIEWER, OWNER)).thenReturn(true);
        when(followRepository.existsByIdFollowerIdAndIdFollowingId(OWNER, VIEWER)).thenReturn(false);

        PublicProfileResponse profile = service.getPublicProfile(VIEWER, OWNER);

        assertThat(profile.getId()).isEqualTo(OWNER);
        assertThat(profile.getUsername()).isEqualTo("bob");
        assertThat(profile.getBio()).isEqualTo("xin chào");
        assertThat(profile.getFollowingCount()).isEqualTo(3L);
        assertThat(profile.getFollowersCount()).isEqualTo(5L);
        assertThat(profile.getLikesCount()).isEqualTo(11L);
        assertThat(profile.getVideosCount()).isEqualTo(4L);
        assertThat(profile.getIsFollowing()).isTrue();
        assertThat(profile.getIsFollowedBy()).isFalse();
        assertThat(profile.getIsSelf()).isFalse();
    }

    @Test
    void ownPageHasNoRelationFlags() {
        when(userRepository.findById(OWNER)).thenReturn(Optional.of(owner(true)));

        PublicProfileResponse profile = service.getPublicProfile(OWNER, OWNER);

        assertThat(profile.getIsSelf()).isTrue();
        assertThat(profile.getIsFollowing()).isFalse();
        assertThat(profile.getIsFollowedBy()).isFalse();
        verify(followRepository, never()).existsByIdFollowerIdAndIdFollowingId(any(), any());
    }

    @Test
    void guestHasNoRelationFlags() {
        when(userRepository.findById(OWNER)).thenReturn(Optional.of(owner(true)));

        PublicProfileResponse profile = service.getPublicProfile(null, OWNER);

        assertThat(profile.getIsSelf()).isFalse();
        assertThat(profile.getIsFollowing()).isFalse();
        assertThat(profile.getIsFollowedBy()).isFalse();
    }

    @Test
    void deactivatedUserIsNotFound() {
        when(userRepository.findById(OWNER)).thenReturn(Optional.of(owner(false)));

        assertThatThrownBy(() -> service.getPublicProfile(VIEWER, OWNER))
                .isInstanceOfSatisfying(AppException.class, e -> assertThat(e.getStatus()).isEqualTo(404));
    }

    @Test
    void unknownUserIsNotFound() {
        when(userRepository.findById(OWNER)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.getPublicProfile(VIEWER, OWNER))
                .isInstanceOfSatisfying(AppException.class, e -> assertThat(e.getStatus()).isEqualTo(404));
    }

    private static User owner(boolean active) {
        return User.builder()
                .id(OWNER)
                .username("bob")
                .displayName("Bob")
                .bio("xin chào")
                .email("bob@example.com")
                .isActive(active)
                .build();
    }
}
