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
import com.jlsp.backend.user.service.FollowService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.HashSet;
import java.util.List;
import java.util.Set;

@Service
@RequiredArgsConstructor
@Slf4j
@Transactional(readOnly = true)
public class FollowServiceImpl implements FollowService {

    private final FollowRepository followRepository;
    private final UserRepository userRepository;

    /** Theo dõi một người dùng; gọi lại khi đã theo dõi thì không làm gì (idempotent). */
    @Override
    @Transactional
    public FollowStatusResponse follow(Long currentUserId, Long targetUserId) {
        if (currentUserId.equals(targetUserId)) {
            throw new AppException(400, "Bạn không thể tự theo dõi chính mình");
        }
        User target = userRepository.findById(targetUserId)
                .orElseThrow(() -> new ResourceNotFoundException("User", "id", targetUserId));
        if (!Boolean.TRUE.equals(target.getIsActive())) {
            throw new AppException(400, "Tài khoản này đã bị khóa");
        }

        if (!followRepository.existsByIdFollowerIdAndIdFollowingId(currentUserId, targetUserId)) {
            User follower = userRepository.getReferenceById(currentUserId);
            followRepository.save(Follow.builder()
                    .id(new FollowId(currentUserId, targetUserId))
                    .follower(follower)
                    .following(target)
                    .build());
            log.info("User {} followed user {}", currentUserId, targetUserId);
        }
        return getStatus(currentUserId, targetUserId);
    }

    @Override
    @Transactional
    public FollowStatusResponse unfollow(Long currentUserId, Long targetUserId) {
        FollowId id = new FollowId(currentUserId, targetUserId);
        if (followRepository.existsById(id)) {
            followRepository.deleteById(id);
            log.info("User {} unfollowed user {}", currentUserId, targetUserId);
        }
        return getStatus(currentUserId, targetUserId);
    }

    @Override
    public FollowStatusResponse getStatus(Long currentUserId, Long targetUserId) {
        boolean following = followRepository.existsByIdFollowerIdAndIdFollowingId(currentUserId, targetUserId);
        boolean followedBy = followRepository.existsByIdFollowerIdAndIdFollowingId(targetUserId, currentUserId);
        return FollowStatusResponse.builder()
                .userId(targetUserId)
                .isFollowing(following)
                .isFollowedBy(followedBy)
                .isMutual(following && followedBy)
                .followersCount(followRepository.countByIdFollowingId(targetUserId))
                .build();
    }

    @Override
    public boolean isMutual(Long userId, Long otherUserId) {
        return followRepository.countFollowsBetween(userId, otherUserId) == 2;
    }

    @Override
    public List<User> getMutualFollows(Long userId) {
        return followRepository.findMutualFollows(userId);
    }

    @Override
    public List<FollowUserResponse> getFollowers(Long userId) {
        Set<Long> followingIds = new HashSet<>(followRepository.findFollowingIdsByFollowerId(userId));
        return followRepository.findFollowersOf(userId).stream()
                .map(f -> toFollowUser(f.getFollower(), f, followingIds.contains(f.getFollower().getId()), true))
                .toList();
    }

    @Override
    public List<FollowUserResponse> getFollowing(Long userId) {
        Set<Long> followerIds = new HashSet<>(followRepository.findFollowerIdsByFollowingId(userId));
        return followRepository.findFollowingOf(userId).stream()
                .map(f -> toFollowUser(f.getFollowing(), f, true, followerIds.contains(f.getFollowing().getId())))
                .toList();
    }

    private static FollowUserResponse toFollowUser(User user, Follow follow, boolean isFollowing, boolean isFollowedBy) {
        return FollowUserResponse.builder()
                .id(user.getId())
                .username(user.getUsername())
                .displayName(user.getDisplayName())
                .avatarUrl(user.getAvatarUrl())
                .jlptLevel(user.getJlptLevel())
                .isFollowing(isFollowing)
                .isFollowedBy(isFollowedBy)
                .followedAt(follow.getCreatedAt())
                .build();
    }
}
