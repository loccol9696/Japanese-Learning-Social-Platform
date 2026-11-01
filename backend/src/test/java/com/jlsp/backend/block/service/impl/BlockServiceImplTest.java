package com.jlsp.backend.block.service.impl;

import com.jlsp.backend.block.dto.BlockedUserResponse;
import com.jlsp.backend.block.entity.UserBlock;
import com.jlsp.backend.block.entity.UserBlockId;
import com.jlsp.backend.block.repository.UserBlockRepository;
import com.jlsp.backend.common.exception.AppException;
import com.jlsp.backend.common.exception.ResourceNotFoundException;
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
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class BlockServiceImplTest {

    private static final long ME = 1L;
    private static final long OTHER = 2L;

    private UserBlockRepository blockRepository;
    private UserRepository userRepository;
    private FollowRepository followRepository;
    private BlockServiceImpl service;

    private User me;
    private User other;

    @BeforeEach
    void setUp() {
        blockRepository = mock(UserBlockRepository.class);
        userRepository = mock(UserRepository.class);
        followRepository = mock(FollowRepository.class);
        service = new BlockServiceImpl(blockRepository, userRepository, followRepository);

        me = User.builder().id(ME).username("me").build();
        other = User.builder().id(OTHER).username("other").displayName("Other").build();
        when(userRepository.findById(OTHER)).thenReturn(Optional.of(other));
        when(userRepository.getReferenceById(ME)).thenReturn(me);
    }

    @Test
    void cannotBlockYourself() {
        assertThatThrownBy(() -> service.block(ME, ME))
                .isInstanceOfSatisfying(AppException.class, e -> assertThat(e.getStatus()).isEqualTo(400));
        verify(blockRepository, never()).save(any());
    }

    @Test
    void cannotBlockAnUnknownUser() {
        when(userRepository.findById(99L)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.block(ME, 99L)).isInstanceOf(ResourceNotFoundException.class);
    }

    @Test
    void blockingStoresTheBlockAndRemovesFollowsInBothDirections() {
        when(followRepository.existsById(new FollowId(ME, OTHER))).thenReturn(true);
        when(followRepository.existsById(new FollowId(OTHER, ME))).thenReturn(true);

        service.block(ME, OTHER);

        ArgumentCaptor<UserBlock> saved = ArgumentCaptor.forClass(UserBlock.class);
        verify(blockRepository).save(saved.capture());
        assertThat(saved.getValue().getId()).isEqualTo(new UserBlockId(ME, OTHER));
        verify(followRepository).deleteById(new FollowId(ME, OTHER));
        verify(followRepository).deleteById(new FollowId(OTHER, ME));
    }

    @Test
    void blockingTwiceDoesNotCreateASecondRow() {
        when(blockRepository.existsByIdBlockerIdAndIdBlockedId(ME, OTHER)).thenReturn(true);

        service.block(ME, OTHER);

        verify(blockRepository, never()).save(any());
    }

    @Test
    void followsThatDoNotExistAreNotDeleted() {
        service.block(ME, OTHER);

        verify(followRepository, never()).deleteById(any());
    }

    @Test
    void unblockOnlyDeletesAnExistingBlock() {
        service.unblock(ME, OTHER);
        verify(blockRepository, never()).deleteById(any());

        when(blockRepository.existsById(new UserBlockId(ME, OTHER))).thenReturn(true);
        service.unblock(ME, OTHER);
        verify(blockRepository).deleteById(new UserBlockId(ME, OTHER));
    }

    @Test
    void blockIsDetectedInEitherDirection() {
        when(blockRepository.existsByIdBlockerIdAndIdBlockedId(OTHER, ME)).thenReturn(true);

        assertThat(service.isBlockedEitherWay(ME, OTHER)).isTrue();
        assertThat(service.hasBlocked(ME, OTHER)).isFalse();
        assertThat(service.hasBlocked(OTHER, ME)).isTrue();
    }

    @Test
    void guestsAreNeverBlocked() {
        assertThat(service.isBlockedEitherWay(null, OTHER)).isFalse();
        assertThat(service.relatedUserIds(null)).isEmpty();
    }

    @Test
    void relatedIdsCombineWhoIBlockedAndWhoBlockedMe() {
        when(blockRepository.findBlockedIds(ME)).thenReturn(List.of(2L, 3L));
        when(blockRepository.findBlockerIds(ME)).thenReturn(List.of(3L, 4L));

        assertThat(service.relatedUserIds(ME)).isEqualTo(Set.of(2L, 3L, 4L));
    }

    @Test
    void listsBlockedUsersWithTheirBlockTime() {
        LocalDateTime when = LocalDateTime.of(2026, 10, 1, 8, 0);
        when(blockRepository.findByIdBlockerIdOrderByCreatedAtDesc(ME)).thenReturn(List.of(
                UserBlock.builder().id(new UserBlockId(ME, OTHER)).blocker(me).blocked(other).createdAt(when).build()));

        List<BlockedUserResponse> result = service.getBlockedUsers(ME);

        assertThat(result).singleElement().satisfies(r -> {
            assertThat(r.getId()).isEqualTo(OTHER);
            assertThat(r.getDisplayName()).isEqualTo("Other");
            assertThat(r.getBlockedAt()).isEqualTo(when);
        });
    }
}
