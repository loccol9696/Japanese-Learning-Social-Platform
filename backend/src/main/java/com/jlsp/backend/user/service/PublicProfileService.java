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
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Xem hồ sơ công khai của người khác và theo dõi / bỏ theo dõi. */
@Service
public class PublicProfileService {

    private final UserRepository userRepository;
    private final FollowRepository followRepository;
    private final VideoRepository videoRepository;

    public PublicProfileService(UserRepository userRepository, FollowRepository followRepository,
            VideoRepository videoRepository) {
        this.userRepository = userRepository;
        this.followRepository = followRepository;
        this.videoRepository = videoRepository;
    }

    /** @param viewerId id người đang xem, null nếu chưa đăng nhập */
    @Transactional(readOnly = true)
    public PublicProfileResponse getPublicProfile(Long userId, Long viewerId) {
        User user = findVisibleUser(userId);
        boolean self = viewerId != null && viewerId.equals(userId);
        boolean following = viewerId != null && !self
                && followRepository.existsByIdFollowerIdAndIdFollowingId(viewerId, userId);

        return PublicProfileResponse.builder()
                .id(user.getId())
                .username(user.getUsername())
                .displayName(user.getDisplayName() != null && !user.getDisplayName().isBlank()
                        ? user.getDisplayName()
                        : user.getUsername())
                .avatarUrl(user.getAvatarUrl())
                .jlptLevel(user.getJlptLevel())
                .bio(user.getBio())
                .followersCount(followRepository.countByIdFollowingId(userId))
                .followingCount(followRepository.countByIdFollowerId(userId))
                .likesCount(videoRepository.sumLikesByUserId(userId))
                .videosCount(videoRepository.countByUserId(userId))
                .isFollowing(following)
                .isSelf(self)
                .build();
    }

    /** Bấm lần đầu là theo dõi, bấm lại là bỏ theo dõi. */
    @Transactional
    public FollowResultResponse toggleFollow(Long followerId, Long targetId) {
        if (followerId.equals(targetId)) {
            throw new AppException(400, "Bạn không thể tự theo dõi chính mình");
        }
        User follower = userRepository.findById(followerId)
                .orElseThrow(() -> new AppException(404, "Không tìm thấy tài khoản"));
        User target = findVisibleUser(targetId);

        FollowId id = new FollowId(followerId, targetId);
        boolean nowFollowing;
        if (followRepository.existsById(id)) {
            followRepository.deleteById(id);
            nowFollowing = false;
        } else {
            followRepository.save(Follow.builder().id(id).follower(follower).following(target).build());
            nowFollowing = true;
        }
        return FollowResultResponse.builder()
                .following(nowFollowing)
                .followersCount(followRepository.countByIdFollowingId(targetId))
                .build();
    }

    /** Tài khoản bị khóa hoặc chưa kích hoạt được coi như không tồn tại với người khác. */
    private User findVisibleUser(Long userId) {
        return userRepository.findById(userId)
                .filter(u -> Boolean.TRUE.equals(u.getIsActive()))
                .orElseThrow(() -> new AppException(404, "Không tìm thấy người dùng"));
    }
}
