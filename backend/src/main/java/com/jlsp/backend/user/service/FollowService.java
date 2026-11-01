package com.jlsp.backend.user.service;

import com.jlsp.backend.user.dto.response.FollowStatusResponse;
import com.jlsp.backend.user.dto.response.FollowUserResponse;
import com.jlsp.backend.user.entity.User;

import java.util.Collection;
import java.util.List;
import java.util.Set;

public interface FollowService {

    FollowStatusResponse follow(Long currentUserId, Long targetUserId);

    FollowStatusResponse unfollow(Long currentUserId, Long targetUserId);

    FollowStatusResponse getStatus(Long currentUserId, Long targetUserId);

    /** Hai người follow lẫn nhau (điều kiện để nhắn tin). */
    boolean isMutual(Long userId, Long otherUserId);

    /** Trong số otherUserIds, những người follow lẫn nhau với userId (một truy vấn cho cả danh sách). */
    Set<Long> findMutualIdsAmong(Long userId, Collection<Long> otherUserIds);

    List<User> getMutualFollows(Long userId);

    /** Số phần tử tối đa của một trang danh sách follower / following (cũng là mặc định). */
    int MAX_LIST_SIZE = 500;

    /**
     * Một trang những người đang theo dõi userId, mới nhất trước; isFollowing cho biết userId đã theo dõi
     * lại chưa. {@code size} bị chặn trong [1, {@link #MAX_LIST_SIZE}].
     */
    List<FollowUserResponse> getFollowers(Long userId, int page, int size);

    /** Một trang những người userId đang theo dõi, mới nhất trước. */
    List<FollowUserResponse> getFollowing(Long userId, int page, int size);
}
