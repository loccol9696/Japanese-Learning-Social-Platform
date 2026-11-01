package com.jlsp.backend.user.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Quan hệ theo dõi giữa người đang đăng nhập và một người dùng khác.
 * mutual = true thì hai bên được nhắn tin cho nhau.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class FollowStatusResponse {

    private Long userId;

    /** Mình đang theo dõi người này. */
    private Boolean isFollowing;

    /** Người này đang theo dõi mình. */
    private Boolean isFollowedBy;

    private Boolean isMutual;

    private Long followersCount;
}
