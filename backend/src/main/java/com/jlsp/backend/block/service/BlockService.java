package com.jlsp.backend.block.service;

import com.jlsp.backend.block.dto.BlockedUserResponse;

import java.util.List;
import java.util.Set;

public interface BlockService {

    /**
     * Chặn một người dùng; gọi lại khi đã chặn thì không làm gì (idempotent). Đồng thời xóa quan hệ
     * theo dõi ở cả hai chiều. Không thể tự chặn mình.
     */
    void block(Long currentUserId, Long targetUserId);

    /** Bỏ chặn; không làm gì nếu chưa chặn. */
    void unblock(Long currentUserId, Long targetUserId);

    /** {@code blocker} đã chặn {@code blocked} (một chiều). */
    boolean hasBlocked(Long blockerId, Long blockedId);

    /** Một trong hai người đã chặn người kia. Id null (khách) luôn là false. */
    boolean isBlockedEitherWay(Long userA, Long userB);

    /**
     * Mọi người có quan hệ chặn với {@code userId} ở bất kỳ chiều nào (mình chặn họ hoặc họ chặn mình).
     * Rỗng khi {@code userId} null (khách).
     */
    Set<Long> relatedUserIds(Long userId);

    List<BlockedUserResponse> getBlockedUsers(Long currentUserId);
}
