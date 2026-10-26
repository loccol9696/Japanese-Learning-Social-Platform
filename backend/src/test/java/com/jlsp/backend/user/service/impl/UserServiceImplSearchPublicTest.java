package com.jlsp.backend.user.service.impl;

import com.jlsp.backend.common.exception.AppException;
import com.jlsp.backend.common.response.PageResponse;
import com.jlsp.backend.common.security.token.RefreshTokenService;
import com.jlsp.backend.user.dto.response.FollowUserResponse;
import com.jlsp.backend.user.entity.User;
import com.jlsp.backend.user.mapper.UserMapper;
import com.jlsp.backend.user.repository.FollowRepository;
import com.jlsp.backend.user.repository.UserRepository;
import com.jlsp.backend.video.repository.VideoRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.assertj.core.api.Assertions.tuple;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class UserServiceImplSearchPublicTest {

    private static final long VIEWER = 1L;
    private static final Pageable PAGE = PageRequest.of(0, 20);

    private UserRepository userRepository;
    private FollowRepository followRepository;
    private UserServiceImpl service;

    @BeforeEach
    void setUp() {
        userRepository = mock(UserRepository.class);
        followRepository = mock(FollowRepository.class);
        service = new UserServiceImpl(userRepository, new UserMapper(), mock(PasswordEncoder.class),
                followRepository, mock(VideoRepository.class), mock(RefreshTokenService.class),
                mock(com.jlsp.backend.topic.service.TopicService.class));
    }

    @Test
    void rejectsQueriesShorterThanTwoCharacters() {
        assertThatThrownBy(() -> service.searchPublicUsers(VIEWER, " a ", PAGE))
                .isInstanceOfSatisfying(AppException.class, e -> assertThat(e.getStatus()).isEqualTo(400));
        verify(userRepository, never()).searchActivePublic(any(), any());
    }

    @Test
    void marksTheRelationWithTheViewerForEachResult() {
        User followed = User.builder().id(2L).username("tanaka").displayName("Tanaka").build();
        User follower = User.builder().id(3L).username("tanabe").displayName("Tanabe").build();
        when(userRepository.searchActivePublic(eq("tana"), any()))
                .thenReturn(new PageImpl<>(List.of(followed, follower), PAGE, 2));
        when(followRepository.findFollowingIdsByFollowerId(VIEWER)).thenReturn(List.of(2L));
        when(followRepository.findFollowerIdsByFollowingId(VIEWER)).thenReturn(List.of(3L));

        PageResponse<FollowUserResponse> result = service.searchPublicUsers(VIEWER, "  tana ", PAGE);

        assertThat(result.getContent())
                .extracting(FollowUserResponse::getId, FollowUserResponse::getIsFollowing,
                        FollowUserResponse::getIsFollowedBy)
                .containsExactly(tuple(2L, true, false), tuple(3L, false, true));
        assertThat(result.getTotalElements()).isEqualTo(2);
    }
}
