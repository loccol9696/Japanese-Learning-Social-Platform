package com.jlsp.backend.user.service;

import com.jlsp.backend.user.dto.response.FollowStatusResponse;
import com.jlsp.backend.user.dto.response.FollowUserResponse;
import com.jlsp.backend.user.entity.User;

import java.util.List;

public interface FollowService {

    FollowStatusResponse follow(Long currentUserId, Long targetUserId);

    FollowStatusResponse unfollow(Long currentUserId, Long targetUserId);

    FollowStatusResponse getStatus(Long currentUserId, Long targetUserId);

    /** Hai người follow lẫn nhau (điều kiện để nhắn tin). */
    boolean isMutual(Long userId, Long otherUserId);

    List<User> getMutualFollows(Long userId);

    /** Những người đang theo dõi userId; isFollowing cho biết userId đã theo dõi lại chưa. */
    List<FollowUserResponse> getFollowers(Long userId);

    /** Những người userId đang theo dõi. */
    List<FollowUserResponse> getFollowing(Long userId);
}
