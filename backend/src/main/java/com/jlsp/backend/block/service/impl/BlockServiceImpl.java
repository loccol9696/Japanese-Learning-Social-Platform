package com.jlsp.backend.block.service.impl;

import com.jlsp.backend.block.dto.BlockedUserResponse;
import com.jlsp.backend.block.entity.UserBlock;
import com.jlsp.backend.block.entity.UserBlockId;
import com.jlsp.backend.block.repository.UserBlockRepository;
import com.jlsp.backend.block.service.BlockService;
import com.jlsp.backend.common.exception.AppException;
import com.jlsp.backend.common.exception.ResourceNotFoundException;
import com.jlsp.backend.user.entity.FollowId;
import com.jlsp.backend.user.entity.User;
import com.jlsp.backend.user.repository.FollowRepository;
import com.jlsp.backend.user.repository.UserRepository;
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
public class BlockServiceImpl implements BlockService {

    private final UserBlockRepository blockRepository;
    private final UserRepository userRepository;
    private final FollowRepository followRepository;

    @Override
    @Transactional
    public void block(Long currentUserId, Long targetUserId) {
        if (currentUserId.equals(targetUserId)) {
            throw new AppException(400, "Bạn không thể tự chặn chính mình");
        }
        User target = userRepository.findById(targetUserId)
                .orElseThrow(() -> new ResourceNotFoundException("User", "id", targetUserId));

        if (!blockRepository.existsByIdBlockerIdAndIdBlockedId(currentUserId, targetUserId)) {
            blockRepository.save(UserBlock.builder()
                    .id(new UserBlockId(currentUserId, targetUserId))
                    .blocker(userRepository.getReferenceById(currentUserId))
                    .blocked(target)
                    .build());
            log.info("User {} đã chặn user {}", currentUserId, targetUserId);
        }

        // Chặn thì không còn theo dõi nhau; vì chat cần theo dõi lẫn nhau nên nhắn tin cũng dừng theo.
        deleteFollowIfExists(currentUserId, targetUserId);
        deleteFollowIfExists(targetUserId, currentUserId);
    }

    private void deleteFollowIfExists(Long followerId, Long followingId) {
        FollowId id = new FollowId(followerId, followingId);
        if (followRepository.existsById(id)) {
            followRepository.deleteById(id);
        }
    }

    @Override
    @Transactional
    public void unblock(Long currentUserId, Long targetUserId) {
        UserBlockId id = new UserBlockId(currentUserId, targetUserId);
        if (blockRepository.existsById(id)) {
            blockRepository.deleteById(id);
            log.info("User {} đã bỏ chặn user {}", currentUserId, targetUserId);
        }
    }

    @Override
    public boolean hasBlocked(Long blockerId, Long blockedId) {
        return blockerId != null && blockedId != null
                && blockRepository.existsByIdBlockerIdAndIdBlockedId(blockerId, blockedId);
    }

    @Override
    public boolean isBlockedEitherWay(Long userA, Long userB) {
        return hasBlocked(userA, userB) || hasBlocked(userB, userA);
    }

    @Override
    public Set<Long> relatedUserIds(Long userId) {
        if (userId == null) {
            return Set.of();
        }
        Set<Long> related = new HashSet<>(blockRepository.findBlockedIds(userId));
        related.addAll(blockRepository.findBlockerIds(userId));
        return related;
    }

    @Override
    public List<BlockedUserResponse> getBlockedUsers(Long currentUserId) {
        return blockRepository.findByIdBlockerIdOrderByCreatedAtDesc(currentUserId).stream()
                .map(b -> BlockedUserResponse.builder()
                        .id(b.getBlocked().getId())
                        .username(b.getBlocked().getUsername())
                        .displayName(b.getBlocked().getDisplayName())
                        .avatarUrl(b.getBlocked().getAvatarUrl())
                        .blockedAt(b.getCreatedAt())
                        .build())
                .toList();
    }
}
