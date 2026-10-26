package com.jlsp.backend.user.service.impl;

import com.jlsp.backend.common.exception.AppException;
import com.jlsp.backend.common.exception.ResourceNotFoundException;
import com.jlsp.backend.user.dto.response.FollowStatusResponse;
import com.jlsp.backend.user.dto.response.FollowUserResponse;
import com.jlsp.backend.user.entity.Follow;
import com.jlsp.backend.user.entity.FollowId;
import com.jlsp.backend.user.entity.User;
import com.jlsp.backend.user.repository.FollowRepository;
import com.jlsp.backend.user.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.assertj.core.api.Assertions.tuple;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class FollowServiceImplTest {

    private static final long ME = 1L;
    private static final long OTHER = 2L;

    private FollowRepository followRepository;
    private UserRepository userRepository;
    private FollowServiceImpl service;

    @BeforeEach
    void setUp() {
        followRepository = mock(FollowRepository.class);
        userRepository = mock(UserRepository.class);
        service = new FollowServiceImpl(followRepository, userRepository,
                mock(com.jlsp.backend.notification.service.NotificationService.class));
    }

    @Test
    void cannotFollowYourself() {
        assertThatThrownBy(() -> service.follow(ME, ME))
                .isInstanceOfSatisfying(AppException.class, e -> assertThat(e.getStatus()).isEqualTo(400));
        verify(followRepository, never()).save(any());
    }

    @Test
    void unknownUserCannotBeFollowed() {
        when(userRepository.findById(OTHER)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.follow(ME, OTHER)).isInstanceOf(ResourceNotFoundException.class);
        verify(followRepository, never()).save(any());
    }

    @Test
    void lockedAccountCannotBeFollowed() {
        when(userRepository.findById(OTHER)).thenReturn(Optional.of(user(OTHER, false)));

        assertThatThrownBy(() -> service.follow(ME, OTHER))
                .isInstanceOfSatisfying(AppException.class, e -> assertThat(e.getStatus()).isEqualTo(400));
        verify(followRepository, never()).save(any());
    }

    @Test
    void followTakesEffectImmediatelyWithoutAnApprovalStep() {
        when(userRepository.findById(OTHER)).thenReturn(Optional.of(user(OTHER, true)));
        when(userRepository.getReferenceById(ME)).thenReturn(user(ME, true));
        // Lần đầu (kiểm tra đã follow chưa) là false, sau khi lưu thì true
        when(followRepository.existsByIdFollowerIdAndIdFollowingId(ME, OTHER)).thenReturn(false, true);
        when(followRepository.existsByIdFollowerIdAndIdFollowingId(OTHER, ME)).thenReturn(false);
        when(followRepository.countByIdFollowingId(OTHER)).thenReturn(1L);

        FollowStatusResponse status = service.follow(ME, OTHER);

        ArgumentCaptor<Follow> saved = ArgumentCaptor.forClass(Follow.class);
        verify(followRepository).save(saved.capture());
        assertThat(saved.getValue().getId()).isEqualTo(new FollowId(ME, OTHER));
        assertThat(status.getIsFollowing()).isTrue();
        assertThat(status.getIsFollowedBy()).isFalse();
        assertThat(status.getIsMutual()).isFalse();
        assertThat(status.getFollowersCount()).isEqualTo(1L);
    }

    @Test
    void followingAgainDoesNothing() {
        when(userRepository.findById(OTHER)).thenReturn(Optional.of(user(OTHER, true)));
        when(followRepository.existsByIdFollowerIdAndIdFollowingId(ME, OTHER)).thenReturn(true);

        service.follow(ME, OTHER);

        verify(followRepository, never()).save(any());
    }

    @Test
    void unfollowRemovesAnExistingRelation() {
        FollowId id = new FollowId(ME, OTHER);
        when(followRepository.existsById(id)).thenReturn(true);

        service.unfollow(ME, OTHER);

        verify(followRepository).deleteById(id);
    }

    @Test
    void unfollowWithoutARelationDeletesNothing() {
        when(followRepository.existsById(new FollowId(ME, OTHER))).thenReturn(false);

        service.unfollow(ME, OTHER);

        verify(followRepository, never()).deleteById(any());
    }

    @Test
    void mutualNeedsBothDirections() {
        when(followRepository.countFollowsBetween(ME, OTHER)).thenReturn(2L, 1L, 0L);

        assertThat(service.isMutual(ME, OTHER)).isTrue();
        assertThat(service.isMutual(ME, OTHER)).isFalse();
        assertThat(service.isMutual(ME, OTHER)).isFalse();
    }

    @Test
    void followersListMarksWhoIFollowBack() {
        // 2 theo dõi mình và mình theo dõi lại; 3 theo dõi mình nhưng mình chưa theo dõi lại
        when(followRepository.findFollowingIdsByFollowerId(ME)).thenReturn(List.of(OTHER));
        when(followRepository.findFollowersOf(ME)).thenReturn(List.of(
                follow(OTHER, ME), follow(3L, ME)));

        List<FollowUserResponse> followers = service.getFollowers(ME);

        assertThat(followers)
                .extracting(FollowUserResponse::getId, FollowUserResponse::getIsFollowing,
                        FollowUserResponse::getIsFollowedBy)
                .containsExactly(tuple(OTHER, true, true), tuple(3L, false, true));
    }

    @Test
    void followingListMarksWhoFollowsMeBack() {
        // Mình theo dõi 2 (2 cũng theo dõi lại) và 3 (3 chưa theo dõi lại)
        when(followRepository.findFollowerIdsByFollowingId(ME)).thenReturn(List.of(OTHER));
        when(followRepository.findFollowingOf(ME)).thenReturn(List.of(
                follow(ME, OTHER), follow(ME, 3L)));

        List<FollowUserResponse> following = service.getFollowing(ME);

        assertThat(following)
                .extracting(FollowUserResponse::getId, FollowUserResponse::getIsFollowing,
                        FollowUserResponse::getIsFollowedBy)
                .containsExactly(tuple(OTHER, true, true), tuple(3L, true, false));
    }

    private static User user(long id, boolean active) {
        return User.builder().id(id).username("user" + id).displayName("User " + id).isActive(active).build();
    }

    private static Follow follow(long followerId, long followingId) {
        return Follow.builder()
                .id(new FollowId(followerId, followingId))
                .follower(user(followerId, true))
                .following(user(followingId, true))
                .createdAt(LocalDateTime.of(2026, 10, 25, 9, 0))
                .build();
    }
}
