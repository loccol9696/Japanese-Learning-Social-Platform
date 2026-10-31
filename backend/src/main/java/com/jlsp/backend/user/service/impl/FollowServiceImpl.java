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
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Collection;
import java.util.List;
import java.util.Set;

@Service
@RequiredArgsConstructor
@Slf4j
@Transactional(readOnly = true)
public class FollowServiceImpl implements FollowService {

    private final FollowRepository followRepository;
    private final UserRepository userRepository;
    private final com.jlsp.backend.block.service.BlockService blockService;
    private final com.jlsp.backend.notification.service.NotificationService notificationService;

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
        if (blockService.isBlockedEitherWay(currentUserId, targetUserId)) {
            throw new AppException(403, "Bạn không thể theo dõi người dùng này");
        }

        if (!followRepository.existsByIdFollowerIdAndIdFollowingId(currentUserId, targetUserId)) {
            User follower = userRepository.getReferenceById(currentUserId);
            followRepository.save(Follow.builder()
                    .id(new FollowId(currentUserId, targetUserId))
                    .follower(follower)
                    .following(target)
                    .build());
            log.info("User {} followed user {}", currentUserId, targetUserId);
            notificationService.notify(targetUserId, currentUserId, com.jlsp.backend.notification.entity.NotificationType.FOLLOW, null, null, null);
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
    public Set<Long> findMutualIdsAmong(Long userId, Collection<Long> otherUserIds) {
        if (otherUserIds.isEmpty()) {
            return Set.of();
        }
        return followRepository.findMutualIdsAmong(userId, otherUserIds);
    }

    @Override
    public List<User> getMutualFollows(Long userId) {
        return followRepository.findMutualFollows(userId);
    }

    @Override
    public List<FollowUserResponse> getFollowers(Long userId, int page, int size) {
        List<Follow> follows = followRepository.findFollowersOf(userId, pageOf(page, size));
        if (follows.isEmpty()) {
            return List.of();
        }
        // Chỉ hỏi quan hệ ngược lại cho những người có trong trang, không tải hết danh sách đang theo dõi.
        Set<Long> followingIds = followRepository.findFollowingIdsAmong(userId,
                follows.stream().map(f -> f.getFollower().getId()).toList());
        return follows.stream()
                .map(f -> toFollowUser(f.getFollower(), f, followingIds.contains(f.getFollower().getId()), true))
                .toList();
    }

    @Override
    public List<FollowUserResponse> getFollowing(Long userId, int page, int size) {
        List<Follow> follows = followRepository.findFollowingOf(userId, pageOf(page, size));
        if (follows.isEmpty()) {
            return List.of();
        }
        Set<Long> followerIds = followRepository.findFollowerIdsAmong(userId,
                follows.stream().map(f -> f.getFollowing().getId()).toList());
        return follows.stream()
                .map(f -> toFollowUser(f.getFollowing(), f, true, followerIds.contains(f.getFollowing().getId())))
                .toList();
    }

    private static Pageable pageOf(int page, int size) {
        return PageRequest.of(Math.max(0, page), Math.min(Math.max(1, size), MAX_LIST_SIZE));
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
